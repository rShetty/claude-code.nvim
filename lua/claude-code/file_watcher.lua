-- File watching and reload system for Claude Code Neovim Plugin
-- Automatically detects and reloads files modified by Claude Code
local config = require("claude-code.config")

local M = {}

-- Internal state
local watcher_state = {
  enabled = false,
  watchers = {}, -- file_path -> { watcher, buffer, last_modified }
  tracked_files = {}, -- Set of files we're tracking
  reload_in_progress = {}, -- Set of files currently being reloaded
  external_changes = {}, -- Buffer tracking external changes
  auto_reload_enabled = true,
}

-- Default file watcher configuration
local file_watcher_defaults = {
  enabled = true,
  auto_reload = true,
  reload_delay = 100, -- ms delay before reloading
  show_reload_notification = true,
  ignore_patterns = {
    "%.git/",
    "%.DS_Store$",
    "%.swp$",
    "%.swo$",
    "%.tmp$",
    "node_modules/",
    ".cache/",
    ".vscode/",
    ".idea/",
  },
  watch_extensions = {
    "lua", "py", "js", "ts", "jsx", "tsx", "go", "rs", "java", "c", "cpp", "h", "hpp",
    "rb", "php", "sh", "bash", "zsh", "fish", "vim", "md", "json", "yaml", "toml", "xml",
  },
  max_file_size = 5 * 1024 * 1024, -- 5MB max file size to watch
}

-- Initialize file watcher system
function M.setup(user_config)
  local cfg = vim.tbl_deep_extend("force", file_watcher_defaults, user_config or {})
  config.update({ file_watcher = cfg })
  
  if cfg.enabled then
    watcher_state.enabled = true
    watcher_state.auto_reload_enabled = cfg.auto_reload
    M.setup_autocommands()
    M.setup_commands()
  end
end

-- Setup autocommands for file watching
function M.setup_autocommands()
  local group = vim.api.nvim_create_augroup("ClaudeCodeFileWatcher", { clear = true })
  
  -- Start watching files when they're opened
  vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
    group = group,
    callback = function(opts)
      local file_path = vim.api.nvim_buf_get_name(opts.buf)
      if file_path and file_path ~= "" and M.should_watch_file(file_path) then
        M.start_watching_file(file_path, opts.buf)
      end
    end,
  })
  
  -- Stop watching files when buffers are deleted
  vim.api.nvim_create_autocmd("BufDelete", {
    group = group,
    callback = function(opts)
      local file_path = vim.api.nvim_buf_get_name(opts.buf)
      if file_path and file_path ~= "" then
        M.stop_watching_file(file_path)
      end
    end,
  })
  
  -- Handle buffer writes (update our tracking)
  vim.api.nvim_create_autocmd("BufWritePost", {
    group = group,
    callback = function(opts)
      local file_path = vim.api.nvim_buf_get_name(opts.buf)
      if file_path and file_path ~= "" and watcher_state.watchers[file_path] then
        M.update_file_timestamp(file_path)
      end
    end,
  })
  
  -- Cleanup on vim exit
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = function()
      M.cleanup()
    end,
  })
  
  -- Handle focus gained (check for external changes)
  vim.api.nvim_create_autocmd("FocusGained", {
    group = group,
    callback = function()
      M.check_all_watched_files()
    end,
  })
end

-- Setup commands for file watcher management
function M.setup_commands()
  -- Toggle file watching
  vim.api.nvim_create_user_command("ClaudeFileWatchToggle", function()
    M.toggle_file_watching()
  end, {
    desc = "Toggle Claude Code file watching",
  })
  
  -- Reload all watched files
  vim.api.nvim_create_user_command("ClaudeFileWatchReload", function()
    M.reload_all_watched_files()
  end, {
    desc = "Reload all watched files",
  })
  
  -- Show file watcher status
  vim.api.nvim_create_user_command("ClaudeFileWatchStatus", function()
    M.show_watcher_status()
  end, {
    desc = "Show file watcher status",
  })
  
  -- Clear file watcher cache
  vim.api.nvim_create_user_command("ClaudeFileWatchClear", function()
    M.clear_watcher_cache()
  end, {
    desc = "Clear file watcher cache",
  })
end

-- Check if a file should be watched
function M.should_watch_file(file_path)
  local cfg = config.get().file_watcher
  if not cfg or not cfg.enabled or not watcher_state.enabled then
    return false
  end
  
  -- Check if file exists and is readable
  local stat = vim.loop.fs_stat(file_path)
  if not stat or stat.type ~= "file" then
    return false
  end
  
  -- Check file size limit
  if stat.size > cfg.max_file_size then
    return false
  end
  
  -- Check ignore patterns
  for _, pattern in ipairs(cfg.ignore_patterns) do
    if file_path:match(pattern) then
      return false
    end
  end
  
  -- Check file extension
  local extension = file_path:match("%.([^.]+)$")
  if extension then
    for _, ext in ipairs(cfg.watch_extensions) do
      if extension == ext then
        return true
      end
    end
  end
  
  return false
end

-- Start watching a file
function M.start_watching_file(file_path, buffer)
  if watcher_state.watchers[file_path] then
    return -- Already watching
  end
  
  local stat = vim.loop.fs_stat(file_path)
  if not stat then
    return
  end
  
  -- Create file system watcher
  local watcher = vim.loop.new_fs_event()
  if not watcher then
    vim.notify("Failed to create file watcher for: " .. file_path, vim.log.levels.WARN)
    return
  end
  
  -- Start watching the file
  local success, err = watcher:start(file_path, {}, function(err_msg, filename, events)
    if err_msg then
      vim.notify("File watcher error: " .. err_msg, vim.log.levels.ERROR)
      return
    end
    
    -- Schedule the file change handler to run in the main thread
    vim.schedule(function()
      M.handle_file_change(file_path, events)
    end)
  end)
  
  if not success then
    vim.notify("Failed to start watching file: " .. file_path .. " - " .. (err or "unknown error"), vim.log.levels.WARN)
    watcher:close()
    return
  end
  
  -- Store watcher information
  watcher_state.watchers[file_path] = {
    watcher = watcher,
    buffer = buffer,
    last_modified = stat.mtime.sec,
    last_size = stat.size,
  }
  
  watcher_state.tracked_files[file_path] = true
  
  if config.get().file_watcher.show_reload_notification then
    vim.notify("Started watching: " .. vim.fn.fnamemodify(file_path, ":t"), vim.log.levels.INFO)
  end
end

-- Stop watching a file
function M.stop_watching_file(file_path)
  local watcher_info = watcher_state.watchers[file_path]
  if not watcher_info then
    return
  end
  
  -- Close the watcher
  if watcher_info.watcher then
    watcher_info.watcher:close()
  end
  
  -- Remove from tracking
  watcher_state.watchers[file_path] = nil
  watcher_state.tracked_files[file_path] = nil
  watcher_state.external_changes[file_path] = nil
end

-- Handle file change event
function M.handle_file_change(file_path, events)
  if watcher_state.reload_in_progress[file_path] then
    return -- Already processing this file
  end
  
  local watcher_info = watcher_state.watchers[file_path]
  if not watcher_info then
    return
  end
  
  -- Check if file still exists
  local stat = vim.loop.fs_stat(file_path)
  if not stat then
    M.stop_watching_file(file_path)
    return
  end
  
  -- Check if file was actually modified (avoid spurious events)
  if stat.mtime.sec <= watcher_info.last_modified and stat.size == watcher_info.last_size then
    return
  end
  
  -- Update our tracking
  watcher_info.last_modified = stat.mtime.sec
  watcher_info.last_size = stat.size
  
  -- Mark as externally changed
  watcher_state.external_changes[file_path] = {
    timestamp = vim.loop.now(),
    events = events,
    size = stat.size,
  }
  
  -- Schedule reload with delay to avoid rapid fire changes
  local cfg = config.get().file_watcher
  vim.defer_fn(function()
    if watcher_state.auto_reload_enabled and cfg.auto_reload then
      M.reload_file(file_path)
    else
      M.notify_external_change(file_path)
    end
  end, cfg.reload_delay)
end

-- Reload a specific file
function M.reload_file(file_path)
  if watcher_state.reload_in_progress[file_path] then
    return
  end
  
  local watcher_info = watcher_state.watchers[file_path]
  if not watcher_info then
    return
  end
  
  local buffer = watcher_info.buffer
  if not buffer or not vim.api.nvim_buf_is_valid(buffer) then
    M.stop_watching_file(file_path)
    return
  end
  
  -- Check if buffer has unsaved changes
  if vim.api.nvim_buf_get_option(buffer, "modified") then
    M.handle_conflict(file_path, buffer)
    return
  end
  
  watcher_state.reload_in_progress[file_path] = true
  
  -- Perform the reload
  local success, err = pcall(function()
    -- Save current cursor position
    local windows = M.get_windows_for_buffer(buffer)
    local cursor_positions = {}
    for _, win in ipairs(windows) do
      if vim.api.nvim_win_is_valid(win) then
        cursor_positions[win] = vim.api.nvim_win_get_cursor(win)
      end
    end
    
    -- Reload the buffer
    vim.api.nvim_buf_call(buffer, function()
      vim.cmd("silent! edit!")
    end)
    
    -- Restore cursor positions
    for win, pos in pairs(cursor_positions) do
      if vim.api.nvim_win_is_valid(win) then
        pcall(vim.api.nvim_win_set_cursor, win, pos)
      end
    end
  end)
  
  watcher_state.reload_in_progress[file_path] = nil
  watcher_state.external_changes[file_path] = nil
  
  if success then
    if config.get().file_watcher.show_reload_notification then
      vim.notify("📄 Reloaded: " .. vim.fn.fnamemodify(file_path, ":t"), vim.log.levels.INFO)
    end
  else
    vim.notify("Failed to reload file: " .. file_path .. " - " .. (err or "unknown error"), vim.log.levels.ERROR)
  end
end

-- Handle file conflict (buffer modified + external change)
function M.handle_conflict(file_path, buffer)
  local filename = vim.fn.fnamemodify(file_path, ":t")
  
  -- Show conflict resolution dialog
  local choices = {
    "Keep buffer version (ignore external changes)",
    "Load external version (lose buffer changes)",
    "Show diff and decide later",
  }
  
  vim.ui.select(choices, {
    prompt = "File conflict detected for " .. filename .. ":",
    format_item = function(item)
      return item
    end,
  }, function(choice, idx)
    if not idx then
      return -- User cancelled
    end
    
    if idx == 1 then
      -- Keep buffer version, stop tracking external changes
      watcher_state.external_changes[file_path] = nil
    elseif idx == 2 then
      -- Load external version
      vim.api.nvim_buf_set_option(buffer, "modified", false)
      M.reload_file(file_path)
    elseif idx == 3 then
      -- Show diff
      M.show_diff(file_path, buffer)
    end
  end)
end

-- Show diff between buffer and file
function M.show_diff(file_path, buffer)
  local filename = vim.fn.fnamemodify(file_path, ":t")
  
  -- Create temporary file with external content
  local temp_file = vim.fn.tempname()
  local source_content = {}
  
  -- Read file content
  local file = io.open(file_path, "r")
  if file then
    for line in file:lines() do
      table.insert(source_content, line)
    end
    file:close()
  end
  
  -- Write to temp file
  local temp = io.open(temp_file, "w")
  if temp then
    for _, line in ipairs(source_content) do
      temp:write(line .. "\n")
    end
    temp:close()
  end
  
  -- Open diff view
  vim.cmd("vertical diffsplit " .. temp_file)
  vim.cmd("file External\\ Changes:\\ " .. filename)
  
  -- Clean up temp file when done
  vim.api.nvim_create_autocmd("BufWipeout", {
    buffer = vim.api.nvim_get_current_buf(),
    once = true,
    callback = function()
      vim.fn.delete(temp_file)
    end,
  })
end

-- Notify about external change without auto-reload
function M.notify_external_change(file_path)
  local filename = vim.fn.fnamemodify(file_path, ":t")
  vim.notify("🔄 External change detected: " .. filename .. " (auto-reload disabled)", vim.log.levels.WARN)
end

-- Update file timestamp after write
function M.update_file_timestamp(file_path)
  local watcher_info = watcher_state.watchers[file_path]
  if not watcher_info then
    return
  end
  
  local stat = vim.loop.fs_stat(file_path)
  if stat then
    watcher_info.last_modified = stat.mtime.sec
    watcher_info.last_size = stat.size
  end
end

-- Get all windows displaying a buffer
function M.get_windows_for_buffer(buffer)
  local windows = {}
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == buffer then
      table.insert(windows, win)
    end
  end
  return windows
end

-- Check all watched files for changes
function M.check_all_watched_files()
  for file_path, _ in pairs(watcher_state.tracked_files) do
    local watcher_info = watcher_state.watchers[file_path]
    if watcher_info then
      local stat = vim.loop.fs_stat(file_path)
      if stat and stat.mtime.sec > watcher_info.last_modified then
        M.handle_file_change(file_path, { "change" })
      end
    end
  end
end

-- Reload all watched files
function M.reload_all_watched_files()
  local count = 0
  for file_path, _ in pairs(watcher_state.tracked_files) do
    if watcher_state.external_changes[file_path] then
      M.reload_file(file_path)
      count = count + 1
    end
  end
  
  if count > 0 then
    vim.notify("Reloaded " .. count .. " files", vim.log.levels.INFO)
  else
    vim.notify("No files needed reloading", vim.log.levels.INFO)
  end
end

-- Toggle file watching
function M.toggle_file_watching()
  watcher_state.enabled = not watcher_state.enabled
  
  if watcher_state.enabled then
    -- Re-enable watching for all open buffers
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_valid(buf) then
        local file_path = vim.api.nvim_buf_get_name(buf)
        if file_path and file_path ~= "" and M.should_watch_file(file_path) then
          M.start_watching_file(file_path, buf)
        end
      end
    end
    vim.notify("File watching enabled", vim.log.levels.INFO)
  else
    -- Stop watching all files
    for file_path, _ in pairs(watcher_state.tracked_files) do
      M.stop_watching_file(file_path)
    end
    vim.notify("File watching disabled", vim.log.levels.INFO)
  end
end

-- Show watcher status
function M.show_watcher_status()
  local status_lines = {
    "Claude Code File Watcher Status",
    "================================",
    "",
    "Enabled: " .. (watcher_state.enabled and "✅ Yes" or "❌ No"),
    "Auto-reload: " .. (watcher_state.auto_reload_enabled and "✅ Yes" or "❌ No"),
    "",
    "Watched files: " .. vim.tbl_count(watcher_state.tracked_files),
    "Files with external changes: " .. vim.tbl_count(watcher_state.external_changes),
    "",
  }
  
  if vim.tbl_count(watcher_state.tracked_files) > 0 then
    table.insert(status_lines, "Currently watched files:")
    for file_path, _ in pairs(watcher_state.tracked_files) do
      local filename = vim.fn.fnamemodify(file_path, ":t")
      local status = watcher_state.external_changes[file_path] and " (⚠️ changed)" or " (✅ synced)"
      table.insert(status_lines, "  • " .. filename .. status)
    end
  else
    table.insert(status_lines, "No files currently being watched.")
  end
  
  -- Display status in floating window
  require("claude-code.ui").show_response(status_lines, {
    title = "File Watcher Status",
    filetype = "text",
  })
end

-- Clear watcher cache
function M.clear_watcher_cache()
  watcher_state.external_changes = {}
  watcher_state.reload_in_progress = {}
  
  vim.notify("File watcher cache cleared", vim.log.levels.INFO)
end

-- Check if file is being watched
function M.is_watching_file(file_path)
  return watcher_state.tracked_files[file_path] ~= nil
end

-- Get list of watched files
function M.get_watched_files()
  local files = {}
  for file_path, _ in pairs(watcher_state.tracked_files) do
    table.insert(files, file_path)
  end
  return files
end

-- Get files with external changes
function M.get_externally_changed_files()
  local files = {}
  for file_path, _ in pairs(watcher_state.external_changes) do
    table.insert(files, file_path)
  end
  return files
end

-- Enable/disable auto-reload
function M.set_auto_reload(enabled)
  watcher_state.auto_reload_enabled = enabled
  config.update({
    file_watcher = {
      auto_reload = enabled
    }
  })
  
  local status = enabled and "enabled" or "disabled"
  vim.notify("Auto-reload " .. status, vim.log.levels.INFO)
end

-- Cleanup function
function M.cleanup()
  -- Stop all watchers
  for file_path, _ in pairs(watcher_state.tracked_files) do
    M.stop_watching_file(file_path)
  end
  
  -- Clear state
  watcher_state = {
    enabled = false,
    watchers = {},
    tracked_files = {},
    reload_in_progress = {},
    external_changes = {},
    auto_reload_enabled = true,
  }
end

return M