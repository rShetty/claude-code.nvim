-- Terminal integration module for Claude Code Neovim Plugin
-- Provides single-key toggle functionality and terminal-based operations
local config = require("claude-code.config")
local ui = require("claude-code.ui")
local api = require("claude-code.api")

local M = {}

-- Internal state
local terminal_state = {
  active = false,
  window = nil,
  buffer = nil,
  toggle_key = nil,
  original_keymap = nil,
  working_dir = nil,
  continue_session = false,
  session_history = {},
}

-- Default terminal configuration
local terminal_defaults = {
  enabled = true,
  toggle_key = "<F12>", -- Single key to toggle Claude Code terminal
  window_config = {
    position = "float", -- "float", "bottom", "right", "top", "left"
    float_opts = {
      relative = "editor",
      width = 0.9,
      height = 0.8,
      row = 0.05,
      col = 0.05,
      border = "rounded",
      title = " Claude Code Terminal ",
      title_pos = "center",
    },
    split_opts = {
      size = 0.3, -- 30% of screen
      position = "bottom", -- "bottom", "right", "top", "left"
    },
  },
  auto_cd_git_root = true,
  session_persistence = true,
  command_args = {
    continue = true,
    custom_variants = {},
  },
}

-- Initialize terminal integration
function M.setup(user_config)
  local cfg = vim.tbl_deep_extend("force", terminal_defaults, user_config or {})
  config.update({ terminal = cfg })
  
  if cfg.enabled then
    M.setup_global_toggle()
    M.setup_commands()
    M.setup_autocommands()
  end
end

-- Setup global toggle key
function M.setup_global_toggle()
  local cfg = config.get().terminal
  if not cfg or not cfg.toggle_key then
    return
  end
  
  -- Store original keymap if it exists
  local existing_map = vim.fn.maparg(cfg.toggle_key, 'n', false, true)
  if existing_map and existing_map.callback then
    terminal_state.original_keymap = existing_map
  end
  
  -- Set global toggle keymap
  vim.keymap.set('n', cfg.toggle_key, function()
    M.toggle_terminal()
  end, {
    desc = "Toggle Claude Code Terminal",
    silent = true,
    noremap = true,
  })
  
  terminal_state.toggle_key = cfg.toggle_key
end

-- Setup terminal commands
function M.setup_commands()
  -- Main terminal command
  vim.api.nvim_create_user_command("ClaudeTerminal", function(opts)
    M.open_terminal(opts.args)
  end, {
    desc = "Open Claude Code terminal",
    nargs = "?",
    complete = M.command_completion,
  })
  
  -- Toggle command
  vim.api.nvim_create_user_command("ClaudeTerminalToggle", M.toggle_terminal, {
    desc = "Toggle Claude Code terminal",
  })
  
  -- Continue session command
  vim.api.nvim_create_user_command("ClaudeTerminalContinue", function()
    M.open_terminal("--continue")
  end, {
    desc = "Continue previous Claude Code session",
  })
  
  -- Clear session command
  vim.api.nvim_create_user_command("ClaudeTerminalClear", M.clear_session, {
    desc = "Clear Claude Code terminal session",
  })
end

-- Setup autocommands for terminal management
function M.setup_autocommands()
  local group = vim.api.nvim_create_augroup("ClaudeCodeTerminal", { clear = true })
  
  -- Auto CD to git root when opening terminal
  vim.api.nvim_create_autocmd("BufEnter", {
    group = group,
    pattern = "*",
    callback = function()
      if terminal_state.active and config.get().terminal.auto_cd_git_root then
        M.update_working_directory()
      end
    end,
  })
  
  -- Save session on terminal close
  vim.api.nvim_create_autocmd("BufWinLeave", {
    group = group,
    callback = function(opts)
      if opts.buf == terminal_state.buffer then
        M.save_session_state()
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
end

-- Toggle terminal window
function M.toggle_terminal()
  if terminal_state.active and terminal_state.window and vim.api.nvim_win_is_valid(terminal_state.window) then
    M.close_terminal()
  else
    M.open_terminal()
  end
end

-- Open terminal window
function M.open_terminal(args)
  if terminal_state.active then
    return
  end
  
  local cfg = config.get().terminal
  args = args or ""
  
  -- Parse command arguments
  local parsed_args = M.parse_command_args(args)
  
  -- Set working directory
  M.update_working_directory()
  
  -- Create terminal buffer
  local buf = M.create_terminal_buffer()
  terminal_state.buffer = buf
  
  -- Create terminal window
  local win = M.create_terminal_window(buf, cfg.window_config)
  terminal_state.window = win
  terminal_state.active = true
  
  -- Setup terminal keymaps
  M.setup_terminal_keymaps(buf)
  
  -- Handle continue session
  if parsed_args.continue or terminal_state.continue_session then
    M.restore_session_state()
  end
  
  -- Initialize Claude Code terminal interface
  M.init_claude_terminal(buf, parsed_args)
  
  vim.notify("Claude Code Terminal opened", vim.log.levels.INFO)
end

-- Close terminal window
function M.close_terminal()
  if not terminal_state.active then
    return
  end
  
  -- Save current session state
  M.save_session_state()
  
  -- Close window if valid
  if terminal_state.window and vim.api.nvim_win_is_valid(terminal_state.window) then
    vim.api.nvim_win_close(terminal_state.window, false)
  end
  
  -- Reset state
  terminal_state.active = false
  terminal_state.window = nil
  -- Keep buffer for session continuity
  
  vim.notify("Claude Code Terminal closed", vim.log.levels.INFO)
end

-- Create terminal buffer
function M.create_terminal_buffer()
  local buf = vim.api.nvim_create_buf(false, true)
  
  -- Set buffer options
  vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
  vim.api.nvim_buf_set_option(buf, "bufhidden", "hide")
  vim.api.nvim_buf_set_option(buf, "swapfile", false)
  vim.api.nvim_buf_set_option(buf, "filetype", "claude-terminal")
  vim.api.nvim_buf_set_name(buf, "Claude Code Terminal")
  
  return buf
end

-- Create terminal window based on configuration
function M.create_terminal_window(buf, window_config)
  local win
  
  if window_config.position == "float" then
    -- Create floating window
    local opts = vim.tbl_deep_extend("force", window_config.float_opts, {})
    
    -- Calculate dimensions
    local width = math.floor(vim.o.columns * opts.width)
    local height = math.floor(vim.o.lines * opts.height)
    local row = math.floor(vim.o.lines * opts.row)
    local col = math.floor(vim.o.columns * opts.col)
    
    opts.width = width
    opts.height = height
    opts.row = row
    opts.col = col
    
    win = vim.api.nvim_open_win(buf, true, opts)
  else
    -- Create split window
    local cmd
    local size = math.floor(
      (window_config.position == "bottom" or window_config.position == "top") 
      and vim.o.lines * window_config.split_opts.size
      or vim.o.columns * window_config.split_opts.size
    )
    
    if window_config.position == "bottom" then
      cmd = "botright " .. size .. "split"
    elseif window_config.position == "top" then
      cmd = "topleft " .. size .. "split"
    elseif window_config.position == "right" then
      cmd = "botright " .. size .. "vsplit"
    elseif window_config.position == "left" then
      cmd = "topleft " .. size .. "vsplit"
    end
    
    vim.cmd(cmd)
    win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(win, buf)
  end
  
  -- Set window options
  vim.api.nvim_win_set_option(win, "wrap", true)
  vim.api.nvim_win_set_option(win, "linebreak", true)
  vim.api.nvim_win_set_option(win, "number", false)
  vim.api.nvim_win_set_option(win, "relativenumber", false)
  vim.api.nvim_win_set_option(win, "cursorline", false)
  
  return win
end

-- Setup terminal-specific keymaps
function M.setup_terminal_keymaps(buf)
  local function map(mode, lhs, rhs, opts)
    opts = opts or {}
    opts.buffer = buf
    opts.noremap = opts.noremap ~= false
    opts.silent = opts.silent ~= false
    vim.keymap.set(mode, lhs, rhs, opts)
  end
  
  -- Close terminal
  map("n", "q", M.close_terminal, { desc = "Close Claude Code Terminal" })
  map("n", "<Esc>", M.close_terminal, { desc = "Close Claude Code Terminal" })
  map("n", terminal_state.toggle_key, M.close_terminal, { desc = "Close Claude Code Terminal" })
  
  -- Terminal navigation
  map("n", "<C-w>", "<C-w>", { desc = "Window navigation" })
  
  -- Quick commands
  map("n", "<CR>", M.execute_current_line, { desc = "Execute current line" })
  map("n", "cc", M.clear_terminal, { desc = "Clear terminal" })
  map("n", "r", M.refresh_context, { desc = "Refresh context" })
  
  -- Insert mode mappings for interactive use
  map("i", "<C-c>", "<Esc>", { desc = "Exit insert mode" })
  map("i", "<C-l>", function() M.clear_terminal() end, { desc = "Clear terminal" })
end

-- Initialize Claude terminal interface
function M.init_claude_terminal(buf, args)
  local welcome_text = {
    "🚀 Claude Code Terminal",
    "==================",
    "",
    "Welcome to Claude Code interactive terminal!",
    "",
    "Commands:",
    "  • Type your questions or code requests",
    "  • Press <CR> to execute current line",
    "  • Type 'help' for more commands",
    "  • Press 'q' or <Esc> to close",
    "",
    "Working directory: " .. (terminal_state.working_dir or vim.fn.getcwd()),
    "",
    "Ready for input...",
    "",
  }
  
  if args.continue and #terminal_state.session_history > 0 then
    table.insert(welcome_text, "🔄 Continuing previous session...")
    table.insert(welcome_text, "")
  end
  
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, welcome_text)
  
  -- Move cursor to end
  local line_count = #welcome_text
  vim.api.nvim_win_set_cursor(terminal_state.window, {line_count, 0})
  
  -- Enter insert mode for immediate interaction
  vim.cmd("startinsert!")
end

-- Parse command line arguments
function M.parse_command_args(args)
  local parsed = {
    continue = false,
    custom_variant = nil,
    extra_args = {},
  }
  
  if not args or args == "" then
    return parsed
  end
  
  -- Split args by whitespace
  local arg_list = vim.split(args, "%s+")
  
  for _, arg in ipairs(arg_list) do
    if arg == "--continue" or arg == "-c" then
      parsed.continue = true
    elseif arg:match("^--variant=(.+)") then
      parsed.custom_variant = arg:match("^--variant=(.+)")
    else
      table.insert(parsed.extra_args, arg)
    end
  end
  
  return parsed
end

-- Execute current line in terminal
function M.execute_current_line()
  if not terminal_state.buffer or not vim.api.nvim_buf_is_valid(terminal_state.buffer) then
    return
  end
  
  local cursor = vim.api.nvim_win_get_cursor(terminal_state.window)
  local line_num = cursor[1]
  local current_line = vim.api.nvim_buf_get_lines(terminal_state.buffer, line_num - 1, line_num, false)[1]
  
  if not current_line or current_line:trim() == "" then
    return
  end
  
  -- Add to session history
  table.insert(terminal_state.session_history, {
    timestamp = os.time(),
    input = current_line,
    type = "user_input",
  })
  
  -- Show processing indicator
  M.append_to_terminal("🤔 Processing: " .. current_line)
  M.append_to_terminal("")
  
  -- Get current context for the API call
  local context = ui.get_current_context()
  context.terminal_mode = true
  context.working_dir = terminal_state.working_dir
  context.session_history = terminal_state.session_history
  
  -- Make API request
  api.request(current_line, context, function(response, error)
    if error then
      M.append_to_terminal("❌ Error: " .. error)
      M.append_to_terminal("")
    else
      M.append_to_terminal("🤖 Claude: " .. response)
      M.append_to_terminal("")
      
      -- Add response to session history
      table.insert(terminal_state.session_history, {
        timestamp = os.time(),
        input = response,
        type = "claude_response",
      })
    end
    
    -- Add prompt for next input
    M.append_to_terminal("➤ ")
    
    -- Move cursor to end of buffer
    local buf_lines = vim.api.nvim_buf_line_count(terminal_state.buffer)
    vim.api.nvim_win_set_cursor(terminal_state.window, {buf_lines, 2})
    
    -- Enter insert mode
    vim.cmd("startinsert!")
  end)
end

-- Append text to terminal buffer
function M.append_to_terminal(text)
  if not terminal_state.buffer or not vim.api.nvim_buf_is_valid(terminal_state.buffer) then
    return
  end
  
  local lines = type(text) == "string" and {text} or text
  local buf_lines = vim.api.nvim_buf_line_count(terminal_state.buffer)
  
  vim.api.nvim_buf_set_lines(terminal_state.buffer, buf_lines, buf_lines, false, lines)
end

-- Clear terminal buffer
function M.clear_terminal()
  if not terminal_state.buffer or not vim.api.nvim_buf_is_valid(terminal_state.buffer) then
    return
  end
  
  vim.api.nvim_buf_set_lines(terminal_state.buffer, 0, -1, false, {
    "🚀 Claude Code Terminal",
    "==================",
    "",
    "Terminal cleared. Ready for input...",
    "",
    "➤ ",
  })
  
  -- Move cursor to end
  vim.api.nvim_win_set_cursor(terminal_state.window, {6, 2})
  vim.cmd("startinsert!")
end

-- Refresh context (reload current file, git status, etc.)
function M.refresh_context()
  M.update_working_directory()
  M.append_to_terminal("🔄 Context refreshed")
  M.append_to_terminal("Working directory: " .. (terminal_state.working_dir or vim.fn.getcwd()))
  M.append_to_terminal("")
end

-- Update working directory (auto CD to git root if enabled)
function M.update_working_directory()
  if not config.get().terminal.auto_cd_git_root then
    terminal_state.working_dir = vim.fn.getcwd()
    return
  end
  
  -- Try to find git root
  local git_root = M.find_git_root()
  if git_root then
    vim.cmd("cd " .. git_root)
    terminal_state.working_dir = git_root
  else
    terminal_state.working_dir = vim.fn.getcwd()
  end
end

-- Find git root directory
function M.find_git_root()
  local current_file = vim.fn.expand("%:p")
  if current_file == "" then
    current_file = vim.fn.getcwd()
  end
  
  local current_dir = vim.fn.fnamemodify(current_file, ":h")
  
  -- Walk up directory tree looking for .git
  while current_dir ~= "/" do
    if vim.fn.isdirectory(current_dir .. "/.git") == 1 then
      return current_dir
    end
    current_dir = vim.fn.fnamemodify(current_dir, ":h")
  end
  
  return nil
end

-- Save current session state
function M.save_session_state()
  if not config.get().terminal.session_persistence then
    return
  end
  
  local session_file = vim.fn.stdpath("cache") .. "/claude-code-terminal-session.json"
  local session_data = {
    working_dir = terminal_state.working_dir,
    session_history = terminal_state.session_history,
    timestamp = os.time(),
  }
  
  local ok, encoded = pcall(vim.json.encode, session_data)
  if ok then
    local file = io.open(session_file, "w")
    if file then
      file:write(encoded)
      file:close()
    end
  end
end

-- Restore previous session state
function M.restore_session_state()
  if not config.get().terminal.session_persistence then
    return
  end
  
  local session_file = vim.fn.stdpath("cache") .. "/claude-code-terminal-session.json"
  local file = io.open(session_file, "r")
  if not file then
    return
  end
  
  local content = file:read("*a")
  file:close()
  
  local ok, session_data = pcall(vim.json.decode, content)
  if ok and session_data then
    terminal_state.working_dir = session_data.working_dir or terminal_state.working_dir
    terminal_state.session_history = session_data.session_history or {}
    
    -- Display session restoration info
    if terminal_state.buffer then
      M.append_to_terminal("🔄 Session restored from " .. os.date("%Y-%m-%d %H:%M:%S", session_data.timestamp))
      M.append_to_terminal("History entries: " .. #terminal_state.session_history)
      M.append_to_terminal("")
    end
  end
end

-- Clear session data
function M.clear_session()
  terminal_state.session_history = {}
  
  local session_file = vim.fn.stdpath("cache") .. "/claude-code-terminal-session.json"
  local file = io.open(session_file, "w")
  if file then
    file:write("{}")
    file:close()
  end
  
  vim.notify("Claude Code terminal session cleared", vim.log.levels.INFO)
end

-- Command completion for :ClaudeTerminal command
function M.command_completion(arg_lead, cmd_line, cursor_pos)
  local completions = {
    "--continue",
    "--variant=custom",
    "-c",
  }
  
  -- Add custom variants from config
  local custom_variants = config.get().terminal.command_args.custom_variants or {}
  for _, variant in ipairs(custom_variants) do
    table.insert(completions, "--variant=" .. variant)
  end
  
  -- Filter completions based on current input
  local matches = {}
  for _, completion in ipairs(completions) do
    if completion:find(arg_lead, 1, true) == 1 then
      table.insert(matches, completion)
    end
  end
  
  return matches
end

-- Check if terminal is currently active
function M.is_active()
  return terminal_state.active
end

-- Get terminal buffer
function M.get_buffer()
  return terminal_state.buffer
end

-- Get terminal window
function M.get_window()
  return terminal_state.window
end

-- Get session history
function M.get_session_history()
  return terminal_state.session_history
end

-- Cleanup function
function M.cleanup()
  if terminal_state.active then
    M.save_session_state()
    M.close_terminal()
  end
  
  -- Restore original keymap if it existed
  if terminal_state.original_keymap and terminal_state.toggle_key then
    vim.keymap.del('n', terminal_state.toggle_key, { silent = true })
    if terminal_state.original_keymap.callback then
      vim.keymap.set('n', terminal_state.toggle_key, terminal_state.original_keymap.callback, {
        desc = terminal_state.original_keymap.desc or "",
        silent = terminal_state.original_keymap.silent,
        noremap = terminal_state.original_keymap.noremap,
      })
    end
  end
  
  terminal_state = {
    active = false,
    window = nil,
    buffer = nil,
    toggle_key = nil,
    original_keymap = nil,
    working_dir = nil,
    continue_session = false,
    session_history = {},
  }
end

return M