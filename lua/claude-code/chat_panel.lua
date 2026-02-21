-- Chat panel for Claude Code Neovim plugin
-- Provides a persistent sidebar chat interface similar to Cursor
local config = require("claude-code.config")
local api = require("claude-code.api")
local ui = require("claude-code.ui")
local utils = require("claude-code.utils")

local M = {}

-- Panel state
local panel_state = {
  is_open = false,
  win_id = nil,
  buf_id = nil,
  chat_history = {},
  current_context = nil,
  input_mode = false,
  input_buf = nil,
  input_win = nil,
  loading = false,
}

-- Configuration defaults
local default_config = {
  width = 50,
  position = "right", -- "left" or "right"
  auto_close = false,
  show_context_info = true,
  max_history = 50,
  keymaps = {
    toggle = "<leader>cp",
    send = "<CR>",
    cancel = "<Esc>",
    clear_history = "<leader>cc",
  },
}

-- Setup function
function M.setup(user_config)
  user_config = user_config or {}
  M.config = vim.tbl_deep_extend("force", default_config, user_config)
  
  -- Register commands
  vim.api.nvim_create_user_command("ClaudeChatPanel", M.toggle, {
    desc = "Toggle Claude Code chat panel",
  })
  
  vim.api.nvim_create_user_command("ClaudeClearHistory", M.clear_history, {
    desc = "Clear Claude Code chat history",
  })
  
  -- Setup global keymap
  vim.keymap.set("n", M.config.keymaps.toggle, M.toggle, {
    desc = "Toggle Claude Code chat panel",
    silent = true,
  })
  
  -- Setup autocommands for context awareness
  M.setup_autocommands()
end

-- Setup autocommands for context updates
function M.setup_autocommands()
  local group = vim.api.nvim_create_augroup("ClaudeChatPanel", { clear = true })
  
  -- Update context when buffer changes
  vim.api.nvim_create_autocmd({"BufEnter", "BufWinEnter"}, {
    group = group,
    callback = function()
      if panel_state.is_open then
        M.update_context()
      end
    end,
  })
  
  -- Clean up on vim exit
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = M.cleanup,
  })
end

-- Toggle panel visibility
function M.toggle()
  if panel_state.is_open then
    M.close()
  else
    M.open()
  end
end

-- Open the chat panel
function M.open()
  if panel_state.is_open then
    return
  end
  
  -- Create buffer if it doesn't exist
  if not panel_state.buf_id or not vim.api.nvim_buf_is_valid(panel_state.buf_id) then
    panel_state.buf_id = vim.api.nvim_create_buf(false, true)
    M.setup_buffer()
  end
  
  -- Calculate window dimensions
  local width = M.config.width
  local height = vim.o.lines - vim.o.cmdheight - 1
  
  -- Determine position
  local col = M.config.position == "right" and (vim.o.columns - width) or 0
  
  -- Create window
  panel_state.win_id = vim.api.nvim_open_win(panel_state.buf_id, false, {
    relative = "editor",
    width = width,
    height = height,
    row = 0,
    col = col,
    style = "minimal",
    border = "single",
    title = " Claude Chat ",
    title_pos = "center",
  })
  
  -- Set window options
  vim.api.nvim_win_set_option(panel_state.win_id, "wrap", true)
  vim.api.nvim_win_set_option(panel_state.win_id, "linebreak", true)
  vim.api.nvim_win_set_option(panel_state.win_id, "cursorline", true)
  
  panel_state.is_open = true
  
  -- Update context and refresh display
  M.update_context()
  M.refresh_display()
  
  -- Adjust main window if needed
  if M.config.position == "right" then
    vim.cmd("vertical resize " .. (vim.o.columns - width - 1))
  else
    vim.cmd("wincmd l | vertical resize " .. (vim.o.columns - width - 1))
  end
end

-- Close the chat panel
function M.close()
  if not panel_state.is_open then
    return
  end
  
  -- Close input window if open
  M.close_input()
  
  -- Close main panel window
  if panel_state.win_id and vim.api.nvim_win_is_valid(panel_state.win_id) then
    vim.api.nvim_win_close(panel_state.win_id, true)
  end
  
  panel_state.is_open = false
  panel_state.win_id = nil
  
  -- Restore main window size
  vim.cmd("wincmd =")
end

-- Setup buffer with keymaps and options
function M.setup_buffer()
  local buf = panel_state.buf_id
  
  -- Buffer options
  vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
  vim.api.nvim_buf_set_option(buf, "swapfile", false)
  vim.api.nvim_buf_set_option(buf, "filetype", "claude-chat")
  vim.api.nvim_buf_set_name(buf, "Claude Chat Panel")
  
  -- Buffer keymaps
  local opts = { buffer = buf, silent = true, noremap = true }
  
  -- Toggle panel
  vim.keymap.set("n", M.config.keymaps.toggle, M.toggle, opts)
  vim.keymap.set("n", "q", M.close, opts)
  
  -- Start new message
  vim.keymap.set("n", "i", M.start_input, opts)
  vim.keymap.set("n", "a", M.start_input, opts)
  vim.keymap.set("n", "o", M.start_input, opts)
  
  -- Clear history
  vim.keymap.set("n", M.config.keymaps.clear_history, M.clear_history, opts)
  
  -- Refresh display
  vim.keymap.set("n", "r", M.refresh_display, opts)
  
  -- Context actions
  vim.keymap.set("n", "c", M.update_context, opts)
end

-- Update current file context
function M.update_context()
  if not panel_state.is_open then
    return
  end
  
  -- Get current context from the main window
  local current_win = vim.api.nvim_get_current_win()
  local target_win = nil
  
  -- Find the main editor window (not the panel)
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if win ~= panel_state.win_id and win ~= panel_state.input_win then
      local buf = vim.api.nvim_win_get_buf(win)
      local buf_name = vim.api.nvim_buf_get_name(buf)
      local buf_type = vim.api.nvim_buf_get_option(buf, "buftype")
      
      -- Skip special buffers
      if buf_type == "" and buf_name ~= "" then
        target_win = win
        break
      end
    end
  end
  
  if target_win then
    -- Temporarily switch to target window to get context
    local original_win = vim.api.nvim_get_current_win()
    vim.api.nvim_set_current_win(target_win)
    
    panel_state.current_context = ui.get_current_context()
    
    -- Switch back to original window
    if vim.api.nvim_win_is_valid(original_win) then
      vim.api.nvim_set_current_win(original_win)
    end
  end
end

-- Refresh the chat display
function M.refresh_display()
  if not panel_state.is_open or not panel_state.buf_id or not vim.api.nvim_buf_is_valid(panel_state.buf_id) then
    return
  end
  
  local lines = {}
  
  -- Header
  table.insert(lines, "╭─ Claude Code Chat ─╮")
  table.insert(lines, "│                    │")
  
  -- Context info
  if M.config.show_context_info and panel_state.current_context then
    local ctx = panel_state.current_context
    local filename = ctx.filename and vim.fn.fnamemodify(ctx.filename, ":t") or "No file"
    local filetype = ctx.filetype or "unknown"
    
    table.insert(lines, "├─ Context ─────────┤")
    table.insert(lines, "│ File: " .. filename)
    table.insert(lines, "│ Type: " .. filetype)
    if ctx.selection then
      table.insert(lines, "│ Selection: Yes")
    end
    table.insert(lines, "│                    │")
  end
  
  -- Instructions
  table.insert(lines, "├─ Controls ────────┤")
  table.insert(lines, "│ i/a/o - Send msg   │")
  table.insert(lines, "│ r - Refresh        │")
  table.insert(lines, "│ c - Update context │")
  table.insert(lines, "│ " .. M.config.keymaps.clear_history .. " - Clear history │")
  table.insert(lines, "│ q - Close panel    │")
  table.insert(lines, "╰────────────────────╯")
  table.insert(lines, "")
  
  -- Chat history
  if #panel_state.chat_history > 0 then
    table.insert(lines, "── Chat History ──")
    table.insert(lines, "")
    
    for i, entry in ipairs(panel_state.chat_history) do
      -- User message
      table.insert(lines, "👤 You:")
      local user_lines = vim.split(entry.user_message, "\n", { plain = true })
      for _, line in ipairs(user_lines) do
        table.insert(lines, "   " .. line)
      end
      table.insert(lines, "")
      
      -- Claude response
      table.insert(lines, "🤖 Claude:")
      if entry.response then
        local response_lines = vim.split(entry.response, "\n", { plain = true })
        for _, line in ipairs(response_lines) do
          table.insert(lines, "   " .. line)
        end
      elseif entry.loading then
        table.insert(lines, "   ⏳ Thinking...")
      elseif entry.error then
        table.insert(lines, "   ❌ Error: " .. entry.error)
      end
      
      table.insert(lines, "")
      table.insert(lines, string.rep("─", 20))
      table.insert(lines, "")
    end
  else
    table.insert(lines, "No chat history yet.")
    table.insert(lines, "Press 'i' to start a conversation!")
    table.insert(lines, "")
  end
  
  -- Update buffer
  vim.api.nvim_buf_set_option(panel_state.buf_id, "modifiable", true)
  vim.api.nvim_buf_set_lines(panel_state.buf_id, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(panel_state.buf_id, "modifiable", false)
  
  -- Scroll to bottom
  if panel_state.win_id and vim.api.nvim_win_is_valid(panel_state.win_id) then
    vim.api.nvim_win_set_cursor(panel_state.win_id, {#lines, 0})
  end
end

-- Start input mode for new message
function M.start_input()
  if panel_state.input_mode or not panel_state.is_open then
    return
  end
  
  -- Create input buffer
  panel_state.input_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(panel_state.input_buf, "buftype", "prompt")
  vim.api.nvim_buf_set_option(panel_state.input_buf, "filetype", "claude-input")
  
  -- Setup prompt
  vim.fn.prompt_setprompt(panel_state.input_buf, "💬 Message: ")
  
  -- Create input window at bottom of panel
  local panel_width = M.config.width
  local input_height = 3
  local panel_col = M.config.position == "right" and (vim.o.columns - panel_width) or 0
  local input_row = vim.o.lines - vim.o.cmdheight - input_height - 1
  
  panel_state.input_win = vim.api.nvim_open_win(panel_state.input_buf, true, {
    relative = "editor",
    width = panel_width,
    height = input_height,
    row = input_row,
    col = panel_col,
    style = "minimal",
    border = "single",
    title = " Send Message ",
    title_pos = "center",
  })
  
  panel_state.input_mode = true
  
  -- Input keymaps
  local opts = { buffer = panel_state.input_buf, silent = true }
  
  vim.keymap.set("i", M.config.keymaps.send, function()
    M.send_message()
  end, opts)
  
  vim.keymap.set({"i", "n"}, M.config.keymaps.cancel, function()
    M.close_input()
  end, opts)
  
  -- Focus input and enter insert mode
  vim.cmd("startinsert")
end

-- Close input window
function M.close_input()
  if not panel_state.input_mode then
    return
  end
  
  if panel_state.input_win and vim.api.nvim_win_is_valid(panel_state.input_win) then
    vim.api.nvim_win_close(panel_state.input_win, true)
  end
  
  if panel_state.input_buf and vim.api.nvim_buf_is_valid(panel_state.input_buf) then
    vim.api.nvim_buf_delete(panel_state.input_buf, { force = true })
  end
  
  panel_state.input_mode = false
  panel_state.input_win = nil
  panel_state.input_buf = nil
  
  -- Return focus to panel
  if panel_state.win_id and vim.api.nvim_win_is_valid(panel_state.win_id) then
    vim.api.nvim_set_current_win(panel_state.win_id)
  end
end

-- Send message to Claude
function M.send_message()
  if not panel_state.input_buf or not vim.api.nvim_buf_is_valid(panel_state.input_buf) then
    return
  end
  
  -- Get message from input buffer
  local lines = vim.api.nvim_buf_get_lines(panel_state.input_buf, 0, -1, false)
  local message = utils.string.trim(table.concat(lines, "\n"):gsub("^💬 Message: ", ""))
  
  if message == "" then
    M.close_input()
    return
  end
  
  -- Add to chat history
  local entry = {
    user_message = message,
    loading = true,
    timestamp = os.time(),
  }
  
  table.insert(panel_state.chat_history, entry)
  
  -- Limit history size
  if #panel_state.chat_history > M.config.max_history then
    table.remove(panel_state.chat_history, 1)
  end
  
  -- Close input and refresh
  M.close_input()
  M.refresh_display()
  
  -- Update context before sending
  M.update_context()
  
  -- Send to Claude API
  panel_state.loading = true
  
  local request_id = api.request(message, panel_state.current_context, function(response, error)
    panel_state.loading = false
    
    -- Update the last entry
    local last_entry = panel_state.chat_history[#panel_state.chat_history]
    if last_entry then
      last_entry.loading = false
      if error then
        last_entry.error = tostring(error)
        vim.notify("Chat request failed: " .. tostring(error), vim.log.levels.ERROR)
      else
        last_entry.response = tostring(response or "")
      end
    end
    
    -- Refresh display
    M.refresh_display()
  end)
  
  -- Handle API request failure
  if not request_id then
    panel_state.loading = false
    local last_entry = panel_state.chat_history[#panel_state.chat_history]
    if last_entry then
      last_entry.loading = false
      last_entry.error = "Failed to start request"
    end
    M.refresh_display()
    vim.notify("Failed to send message to Claude", vim.log.levels.ERROR)
  end
end

-- Clear chat history
function M.clear_history()
  panel_state.chat_history = {}
  M.refresh_display()
  vim.notify("Chat history cleared", vim.log.levels.INFO)
end

-- Check if panel is open
function M.is_open()
  return panel_state.is_open
end

-- Get chat history
function M.get_history()
  return vim.deepcopy(panel_state.chat_history)
end

-- Cleanup function
function M.cleanup()
  if panel_state.is_open then
    M.close()
  end
  
  if panel_state.buf_id and vim.api.nvim_buf_is_valid(panel_state.buf_id) then
    vim.api.nvim_buf_delete(panel_state.buf_id, { force = true })
  end
  
  -- Reset state
  panel_state = {
    is_open = false,
    win_id = nil,
    buf_id = nil,
    chat_history = {},
    current_context = nil,
    input_mode = false,
    input_buf = nil,
    input_win = nil,
    loading = false,
  }
end

return M