-- UI system for Claude Code Neovim plugin
local config = require("claudeai.config")
local M = {}

-- Internal state
local floating_windows = {}
local progress_timers = {}

-- Create floating window
local function create_float(opts)
  opts = opts or {}
  local cfg = config.get().ui
  
  -- Calculate dimensions
  local width = math.floor(vim.o.columns * (opts.width or cfg.float_width))
  local height = math.floor(vim.o.lines * (opts.height or cfg.float_height))
  
  -- Calculate position (centered)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)
  
  -- Create buffer
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
  vim.api.nvim_buf_set_option(buf, "filetype", opts.filetype or "markdown")
  
  -- Window options
  local win_opts = {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    border = cfg.float_border,
    title = opts.title or "Claude Code",
    title_pos = "center",
    style = "minimal",
  }
  
  -- Create window
  local win = vim.api.nvim_open_win(buf, true, win_opts)
  
  -- Window-specific settings
  vim.api.nvim_win_set_option(win, "wrap", true)
  vim.api.nvim_win_set_option(win, "linebreak", true)
  
  -- Key mappings for the floating window
  local function map_buf(mode, lhs, rhs, opts_map)
    opts_map = opts_map or {}
    opts_map.buffer = buf
    opts_map.noremap = true
    opts_map.silent = true
    vim.keymap.set(mode, lhs, rhs, opts_map)
  end
  
  -- Close window mappings
  map_buf("n", "q", function() M.close_window(win) end)
  map_buf("n", "<Esc>", function() M.close_window(win) end)
  
  -- Copy content mapping
  map_buf("n", "y", function()
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local content = table.concat(lines, "\n")
    vim.fn.setreg("+", content)
    vim.notify("Content copied to clipboard", vim.log.levels.INFO)
  end)
  
  -- Store window reference
  floating_windows[win] = {
    buf = buf,
    title = opts.title or "Claude Code",
    created_at = os.time()
  }
  
  return win, buf
end

-- Close floating window
function M.close_window(win)
  if floating_windows[win] then
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
    floating_windows[win] = nil
  end
end

-- Close all floating windows
function M.close_all_windows()
  for win, _ in pairs(floating_windows) do
    M.close_window(win)
  end
end

-- Show loading indicator
function M.show_loading(title, message)
  title = title or "Claude Code"
  message = message or "Processing request..."
  
  local win, buf = create_float({
    title = title .. " - Loading",
    width = 0.4,
    height = 0.2,
  })
  
  -- Loading animation frames
  local frames = {"⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"}
  local frame_idx = 1
  
  local function update_loading()
    if not vim.api.nvim_win_is_valid(win) then
      return
    end
    
    local content = {
      "",
      "  " .. frames[frame_idx] .. " " .. message,
      "",
      "  Press <Esc> to cancel",
      ""
    }
    
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, content)
    frame_idx = frame_idx % #frames + 1
  end
  
  -- Start animation timer
  local timer = vim.loop.new_timer()
  timer:start(0, 100, vim.schedule_wrap(update_loading))
  
  -- Store timer reference
  progress_timers[win] = timer
  
  return win
end

-- Hide loading indicator
function M.hide_loading(win)
  if progress_timers[win] then
    progress_timers[win]:stop()
    progress_timers[win]:close()
    progress_timers[win] = nil
  end
  
  if win then
    M.close_window(win)
  end
end

-- Display Claude Code response
function M.show_response(content, opts)
  opts = opts or {}
  local cfg = config.get().ui
  
  -- Close loading window if provided
  if opts.loading_win then
    M.hide_loading(opts.loading_win)
  end
  
  -- Determine content type and format
  local filetype = opts.filetype or "markdown"
  local title = opts.title or "Claude Code Response"
  
  -- Detect code blocks and set appropriate filetype
  if type(content) == "string" and content:match("```%w+") then
    filetype = "markdown"
  elseif opts.language then
    filetype = opts.language
  end
  
  -- Create window
  local win, buf = create_float({
    title = title,
    filetype = filetype,
    width = opts.width,
    height = opts.height,
  })
  
  -- Format content
  local lines
  if type(content) == "string" then
    lines = vim.split(content, "\n", { plain = true })
  else
    lines = content
  end
  
  -- Set content
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  
  -- Make buffer read-only
  vim.api.nvim_buf_set_option(buf, "readonly", true)
  vim.api.nvim_buf_set_option(buf, "modifiable", false)
  
  -- Apply syntax highlighting if enabled
  if cfg.syntax_highlighting and filetype ~= "markdown" then
    vim.api.nvim_buf_set_option(buf, "filetype", filetype)
  end
  
  -- Auto-close timer for success messages
  if opts.auto_close and cfg.auto_close_delay > 0 then
    vim.defer_fn(function()
      if vim.api.nvim_win_is_valid(win) then
        M.close_window(win)
      end
    end, cfg.auto_close_delay)
  end
  
  -- Add additional key mappings based on content type
  local function map_buf(mode, lhs, rhs, map_opts)
    map_opts = map_opts or {}
    map_opts.buffer = buf
    map_opts.noremap = true
    map_opts.silent = true
    vim.keymap.set(mode, lhs, rhs, map_opts)
  end
  
  -- Apply code action if it's a code generation response
  if opts.apply_code then
    map_buf("n", "<CR>", function()
      M.apply_code_suggestion(content, opts)
      M.close_window(win)
    end, { desc = "Apply code suggestion" })
    
    map_buf("n", "a", function()
      M.apply_code_suggestion(content, opts)
      M.close_window(win)
    end, { desc = "Apply code suggestion" })
    
    -- Show help text
    local help_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    table.insert(help_lines, "")
    table.insert(help_lines, "Press <CR> or 'a' to apply code, 'y' to copy, 'q' to close")
    vim.api.nvim_buf_set_option(buf, "modifiable", true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, help_lines)
    vim.api.nvim_buf_set_option(buf, "modifiable", false)
  end
  
  return win
end

-- Show error message
function M.show_error(message, opts)
  opts = opts or {}
  
  -- Close loading window if provided
  if opts.loading_win then
    M.hide_loading(opts.loading_win)
  end
  
  local title = opts.title or "Claude Code - Error"
  local content = {
    "",
    "❌ " .. message,
    "",
    "Press 'q' or <Esc> to close",
    ""
  }
  
  local win = create_float({
    title = title,
    width = 0.6,
    height = 0.3,
  })
  
  local buf = floating_windows[win].buf
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, content)
  vim.api.nvim_buf_set_option(buf, "readonly", true)
  vim.api.nvim_buf_set_option(buf, "modifiable", false)
  
  -- Highlight error message
  vim.api.nvim_buf_add_highlight(buf, -1, "ErrorMsg", 1, 0, -1)
  
  -- Auto-close error after delay
  if config.get().ui.auto_close_delay > 0 then
    vim.defer_fn(function()
      if vim.api.nvim_win_is_valid(win) then
        M.close_window(win)
      end
    end, config.get().ui.auto_close_delay + 2000) -- Longer delay for errors
  end
  
  return win
end

-- Show success message
function M.show_success(message, opts)
  opts = opts or {}
  
  local title = opts.title or "Claude Code - Success"
  local content = {
    "",
    "✅ " .. message,
    "",
    "Press 'q' or <Esc> to close",
    ""
  }
  
  local win = create_float({
    title = title,
    width = 0.5,
    height = 0.2,
  })
  
  local buf = floating_windows[win].buf
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, content)
  vim.api.nvim_buf_set_option(buf, "readonly", true)
  vim.api.nvim_buf_set_option(buf, "modifiable", false)
  
  -- Highlight success message
  vim.api.nvim_buf_add_highlight(buf, -1, "DiagnosticOk", 1, 0, -1)
  
  -- Auto-close success message
  vim.defer_fn(function()
    if vim.api.nvim_win_is_valid(win) then
      M.close_window(win)
    end
  end, config.get().ui.auto_close_delay)
  
  return win
end

-- Apply code suggestion to current buffer
function M.apply_code_suggestion(content, opts)
  opts = opts or {}
  
  -- Extract code from markdown if needed
  local code = content
  if type(content) == "string" and content:match("```") then
    -- Extract code from first code block
    local code_block = content:match("```%w*\n(.-)```")
    if code_block then
      code = code_block
    end
  end
  
  -- Get current buffer and cursor position
  local buf = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row = cursor[1]
  
  -- Split code into lines
  local lines = vim.split(code, "\n", { plain = true })
  
  -- Apply based on mode
  if opts.mode == "replace_selection" and opts.start_line and opts.end_line then
    -- Replace selected lines
    vim.api.nvim_buf_set_lines(buf, opts.start_line - 1, opts.end_line, false, lines)
  elseif opts.mode == "replace_function" then
    -- Replace entire function (would need function detection)
    vim.api.nvim_buf_set_lines(buf, row - 1, row - 1, false, lines)
  else
    -- Insert at current cursor position
    vim.api.nvim_buf_set_lines(buf, row - 1, row - 1, false, lines)
  end
  
  -- Move cursor to end of inserted code
  local new_row = row + #lines - 1
  vim.api.nvim_win_set_cursor(0, {new_row, 0})
  
  M.show_success("Code applied successfully")
end

-- Show input dialog
function M.input_dialog(prompt, callback, opts)
  opts = opts or {}
  
  local title = opts.title or "Claude Code - Input"
  local default_text = opts.default or ""
  
  -- Use vim.ui.input if available (better integration)
  if vim.ui and vim.ui.input then
    vim.ui.input({
      prompt = prompt .. ": ",
      default = default_text,
    }, callback)
    return
  end
  
  -- Fallback to command line input
  vim.schedule(function()
    local ok, result = pcall(vim.fn.input, prompt .. ": ", default_text)
    if ok and result and result ~= "" then
      callback(result)
    else
      callback(nil)
    end
  end)
end

-- Show selection dialog
function M.select_dialog(items, callback, opts)
  opts = opts or {}
  
  local title = opts.title or "Claude Code - Select"
  local prompt = opts.prompt or "Select an option:"
  
  -- Use vim.ui.select if available
  if vim.ui and vim.ui.select then
    vim.ui.select(items, {
      prompt = prompt,
      format_item = opts.format_item,
    }, callback)
    return
  end
  
  -- Fallback to simple list
  local formatted_items = {}
  for i, item in ipairs(items) do
    local formatted = opts.format_item and opts.format_item(item) or tostring(item)
    table.insert(formatted_items, i .. ". " .. formatted)
  end
  
  local content = {prompt, ""}
  vim.list_extend(content, formatted_items)
  table.insert(content, "")
  table.insert(content, "Enter number and press <CR>:")
  
  local win, buf = create_float({
    title = title,
    width = 0.6,
    height = 0.4,
  })
  
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, content)
  
  -- Handle input
  local function handle_input()
    local input = vim.fn.input("Select (1-" .. #items .. "): ")
    local num = tonumber(input)
    M.close_window(win)
    
    if num and num >= 1 and num <= #items then
      callback(items[num], num)
    else
      callback(nil)
    end
  end
  
  vim.keymap.set("n", "<CR>", handle_input, { buffer = buf, noremap = true, silent = true })
end

-- Get current context (file content, selection, etc.)
function M.get_current_context()
  local context = {}
  
  -- Current buffer info
  local buf = vim.api.nvim_get_current_buf()
  context.filename = vim.api.nvim_buf_get_name(buf)
  context.filetype = vim.api.nvim_buf_get_option(buf, "filetype")
  context.language = context.filetype
  
  -- Get file content
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  context.file_content = table.concat(lines, "\n")
  
  -- Get selection if in visual mode
  local mode = vim.fn.mode()
  if mode == "v" or mode == "V" or mode == "\22" then -- \22 is Ctrl-V
    local start_pos = vim.fn.getpos("'<")
    local end_pos = vim.fn.getpos("'>")
    
    if start_pos and end_pos then
      local start_line = start_pos[2] - 1
      local end_line = end_pos[2]
      local selected_lines = vim.api.nvim_buf_get_lines(buf, start_line, end_line, false)
      context.selection = table.concat(selected_lines, "\n")
      context.start_line = start_line + 1
      context.end_line = end_line
    end
  end
  
  -- Get cursor context
  local cursor = vim.api.nvim_win_get_cursor(0)
  context.cursor_line = cursor[1]
  context.cursor_col = cursor[2]
  
  -- Get surrounding context for completion
  local context_lines = config.get().features.completion.max_context_lines
  local start_line = math.max(0, cursor[1] - context_lines)
  local end_line = math.min(#lines, cursor[1] + context_lines)
  
  local before_cursor = vim.api.nvim_buf_get_lines(buf, start_line, cursor[1], false)
  local after_cursor = vim.api.nvim_buf_get_lines(buf, cursor[1], end_line, false)
  
  context.before_cursor = table.concat(before_cursor, "\n")
  context.after_cursor = table.concat(after_cursor, "\n")
  
  return context
end

-- Cleanup function
function M.cleanup()
  -- Close all windows
  M.close_all_windows()
  
  -- Stop all timers
  for win, timer in pairs(progress_timers) do
    timer:stop()
    timer:close()
  end
  progress_timers = {}
end

return M