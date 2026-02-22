-- Modern Chat Panel for Claude Code Neovim plugin
-- Enhanced with smart navigation, auto-input, and modern UI
local config = require("claude-code.config")
local api = require("claude-code.api")
local ui = require("claude-code.ui")
local utils = require("claude-code.utils")

local M = {}

-- Enhanced panel state with navigation tracking
local panel_state = {
  is_open = false,
  main_win = nil,
  main_buf = nil,
  input_win = nil,
  input_buf = nil,
  chat_history = {},
  current_context = nil,
  loading = false,
  previous_win = nil, -- Track previous window for smart navigation
  input_history = {}, -- Store input history
  input_history_pos = 0,
  animation_timer = nil,
  focus_mode = "input", -- "input" or "panel"
}

-- Enhanced configuration with modern UI features
local default_config = {
  width = 50,
  position = "right", -- "left" or "right"
  auto_close = false,
  auto_input = true, -- Auto-enter input mode
  show_context_info = true,
  max_history = 50,
  input_height = 3, -- Multi-line input area
  smart_resize = true,
  modern_ui = {
    enabled = true,
    animations = true,
    icons = {
      user = "👤",
      claude = "🤖",
      loading = "⏳",
      error = "❌",
      success = "✅",
      input = "💬",
    },
    colors = {
      border = "FloatBorder",
      title = "Title",
      user_message = "Normal",
      claude_message = "Comment",
      input_prompt = "Question",
      loading = "WarningMsg",
      error = "ErrorMsg",
    },
  },
  navigation = {
    enable_window_nav = true,
    smart_focus = true,
    focus_on_open = "input",
  },
  keymaps = {
    toggle = "<leader>cp",
    send = "<CR>",
    cancel = "<Esc>",
    clear_history = "<leader>cc",
    focus_input = "<C-i>",
    focus_panel = "<C-p>",
    nav_left = "<C-w>h",
    nav_right = "<C-w>l",
    nav_up = "<C-w>k",
    nav_down = "<C-w>j",
  },
}

-- Enhanced setup function
function M.setup(user_config)
  user_config = user_config or {}
  M.config = vim.tbl_deep_extend("force", default_config, user_config)
  
  -- Register commands
  vim.api.nvim_create_user_command("ClaudeChatPanel", M.toggle, {
    desc = "Toggle modern Claude Code chat panel",
  })
  
  vim.api.nvim_create_user_command("ClaudeClearHistory", M.clear_history, {
    desc = "Clear Claude Code chat history",
  })
  
  vim.api.nvim_create_user_command("ClaudeChatStatus", M.show_api_status, {
    desc = "Check Claude Code API status",
  })
  
  vim.api.nvim_create_user_command("ClaudeFocusInput", M.focus_input, {
    desc = "Focus Claude chat input",
  })
  
  vim.api.nvim_create_user_command("ClaudeFocusPanel", M.focus_panel, {
    desc = "Focus Claude chat panel",
  })
  
  -- Setup global keymaps
  vim.keymap.set("n", M.config.keymaps.toggle, M.toggle, {
    desc = "Toggle Claude Code chat panel",
    silent = true,
  })
  
  -- Setup navigation keymaps globally if enabled
  if M.config.navigation.enable_window_nav then
    M.setup_global_navigation()
  end
  
  -- Setup autocommands for context awareness
  M.setup_autocommands()
end

-- Setup global navigation overrides
function M.setup_global_navigation()
  -- Override default window navigation when panel is active
  local function create_nav_wrapper(direction)
    return function()
      if panel_state.is_open then
        M.smart_navigate(direction)
      else
        vim.cmd("wincmd " .. direction:sub(1,1))
      end
    end
  end
  
  -- Only set up global navigation if explicitly enabled
  if M.config.navigation.enable_window_nav then
    vim.keymap.set("n", "<C-w>h", create_nav_wrapper("left"), { 
      desc = "Navigate left (Claude-aware)", 
      silent = true 
    })
    vim.keymap.set("n", "<C-w>l", create_nav_wrapper("right"), { 
      desc = "Navigate right (Claude-aware)", 
      silent = true 
    })
    vim.keymap.set("n", "<C-w>j", create_nav_wrapper("down"), { 
      desc = "Navigate down (Claude-aware)", 
      silent = true 
    })
    vim.keymap.set("n", "<C-w>k", create_nav_wrapper("up"), { 
      desc = "Navigate up (Claude-aware)", 
      silent = true 
    })
  end
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

-- Open the modern chat panel with auto-input
function M.open()
  if panel_state.is_open then
    -- If already open, just focus the input
    M.focus_input()
    return
  end
  
  -- Clean up any existing buffers from previous sessions
  M.cleanup_buffers()
  
  -- Store previous window for navigation
  panel_state.previous_win = vim.api.nvim_get_current_win()
  
  -- Calculate dimensions accounting for window borders (each border adds 2 rows)
  local width = M.config.width
  local available_height = vim.o.lines - vim.o.cmdheight - 1
  local input_height = M.config.input_height
  -- Both windows have borders: main (height+2) + input (height+2)
  local main_height = math.max(5, available_height - input_height - 4)
  local col = M.config.position == "right" and (vim.o.columns - width - 2) or 0

  local border_style = M.config.modern_ui.enabled and "rounded" or "single"

  -- Create main chat buffer and window
  panel_state.main_buf = vim.api.nvim_create_buf(false, true)
  M.setup_main_buffer()

  local main_config = {
    relative = "editor",
    width = width,
    height = main_height,
    row = 0,
    col = col,
    style = "minimal",
    border = border_style,
    title = M.get_panel_title(),
    title_pos = "center",
  }
  panel_state.main_win = vim.api.nvim_open_win(panel_state.main_buf, false, main_config)

  -- Create persistent input buffer and window
  panel_state.input_buf = vim.api.nvim_create_buf(false, true)
  M.setup_input_buffer()

  -- Place input window right below the main window's bottom border
  -- Build config explicitly to guarantee width/col match the main window
  local input_row = main_height + 2
  local input_config = {
    relative = "editor",
    width = width,
    height = input_height,
    row = input_row,
    col = col,
    style = "minimal",
    border = border_style,
    title = " " .. M.config.modern_ui.icons.input .. " Input ",
    title_pos = "center",
  }
  panel_state.input_win = vim.api.nvim_open_win(panel_state.input_buf, M.config.auto_input, input_config)
  
  -- Setup window options
  M.setup_window_options()
  
  panel_state.is_open = true
  
  -- Update context and refresh
  M.update_context()
  M.refresh_display()
  
  -- Setup navigation keymaps
  if M.config.navigation.enable_window_nav then
    M.setup_navigation_keymaps()
  end
  
  -- Setup additional keymaps
  M.setup_after_open()
  
  -- Adjust main window layout
  M.adjust_main_layout()
  
  -- Auto-focus based on config
  M.handle_auto_focus()
  
  -- Start animations if enabled
  if M.config.modern_ui.animations then
    M.start_opening_animation()
  end
end

-- Helper functions for modern UI

-- Get dynamic panel title with status
function M.get_panel_title()
  local base_title = " Claude Chat "
  if panel_state.loading then
    return M.config.modern_ui.icons.loading .. base_title
  elseif #panel_state.chat_history > 0 then
    return M.config.modern_ui.icons.claude .. base_title .. "(" .. #panel_state.chat_history .. ")"
  else
    return M.config.modern_ui.icons.claude .. base_title
  end
end

-- Setup main chat buffer
function M.setup_main_buffer()
  local buf = panel_state.main_buf
  vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
  vim.api.nvim_buf_set_option(buf, "swapfile", false)
  vim.api.nvim_buf_set_option(buf, "filetype", "claude-chat")
  vim.api.nvim_buf_set_option(buf, "modifiable", false)
  vim.api.nvim_buf_set_name(buf, "Claude Chat")
end

-- Setup input buffer with prompt
function M.setup_input_buffer()
  local buf = panel_state.input_buf
  vim.api.nvim_buf_set_option(buf, "buftype", "prompt")
  vim.api.nvim_buf_set_option(buf, "filetype", "claude-input")
  vim.api.nvim_buf_set_option(buf, "swapfile", false)
  vim.api.nvim_buf_set_name(buf, "Claude Input")
  
  -- Setup prompt with modern icon
  vim.fn.prompt_setprompt(buf, M.config.modern_ui.icons.input .. " ")
  
  -- Setup input keymaps
  M.setup_input_keymaps(buf)
end

-- Setup window display options
function M.setup_window_options()
  -- Main window options
  if panel_state.main_win and vim.api.nvim_win_is_valid(panel_state.main_win) then
    vim.api.nvim_win_set_option(panel_state.main_win, "wrap", true)
    vim.api.nvim_win_set_option(panel_state.main_win, "linebreak", true)
    vim.api.nvim_win_set_option(panel_state.main_win, "cursorline", false)
    vim.api.nvim_win_set_option(panel_state.main_win, "number", false)
    vim.api.nvim_win_set_option(panel_state.main_win, "relativenumber", false)
    vim.api.nvim_win_set_option(panel_state.main_win, "signcolumn", "no")
    vim.api.nvim_win_set_option(panel_state.main_win, "foldcolumn", "0")
  end
  
  -- Input window options
  if panel_state.input_win and vim.api.nvim_win_is_valid(panel_state.input_win) then
    vim.api.nvim_win_set_option(panel_state.input_win, "wrap", true)
    vim.api.nvim_win_set_option(panel_state.input_win, "cursorline", false)
    vim.api.nvim_win_set_option(panel_state.input_win, "number", false)
    vim.api.nvim_win_set_option(panel_state.input_win, "relativenumber", false)
    vim.api.nvim_win_set_option(panel_state.input_win, "signcolumn", "no")
    vim.api.nvim_win_set_option(panel_state.input_win, "foldcolumn", "0")
    vim.api.nvim_win_set_option(panel_state.input_win, "winhighlight", "Normal:Normal,FloatBorder:FloatBorder")
  end
end

-- Setup navigation keymaps for seamless window switching
function M.setup_navigation_keymaps()
  local function setup_nav_for_buffer(buf, win_type)
    local opts = { buffer = buf, silent = true, noremap = true }
    
    -- Smart window navigation
    vim.keymap.set({"n", "i"}, M.config.keymaps.nav_left, function()
      M.smart_navigate("left")
    end, opts)
    
    vim.keymap.set({"n", "i"}, M.config.keymaps.nav_right, function()
      M.smart_navigate("right")
    end, opts)
    
    vim.keymap.set({"n", "i"}, M.config.keymaps.nav_up, function()
      M.smart_navigate("up")
    end, opts)
    
    vim.keymap.set({"n", "i"}, M.config.keymaps.nav_down, function()
      M.smart_navigate("down")
    end, opts)
    
    -- Focus switching
    vim.keymap.set({"n", "i"}, M.config.keymaps.focus_input, function()
      M.focus_input()
    end, opts)
    
    vim.keymap.set({"n", "i"}, M.config.keymaps.focus_panel, function()
      M.focus_panel()
    end, opts)
  end
  
  -- Setup for both buffers
  if panel_state.main_buf then
    setup_nav_for_buffer(panel_state.main_buf, "main")
  end
  if panel_state.input_buf then
    setup_nav_for_buffer(panel_state.input_buf, "input")
  end
end

-- Smart navigation between windows
function M.smart_navigate(direction)
  local current_win = vim.api.nvim_get_current_win()
  
  -- If we're in the chat panel and trying to go left/right, navigate to editor
  if (current_win == panel_state.main_win or current_win == panel_state.input_win) then
    if direction == "left" and M.config.position == "right" then
      -- Go to previous window (editor)
      if panel_state.previous_win and vim.api.nvim_win_is_valid(panel_state.previous_win) then
        vim.api.nvim_set_current_win(panel_state.previous_win)
      else
        vim.cmd("wincmd h")
      end
      return
    elseif direction == "right" and M.config.position == "left" then
      -- Go to next window (editor)
      vim.cmd("wincmd l")
      return
    elseif direction == "up" and current_win == panel_state.input_win then
      -- Go from input to main panel
      vim.api.nvim_set_current_win(panel_state.main_win)
      return
    elseif direction == "down" and current_win == panel_state.main_win then
      -- Go from main panel to input
      vim.api.nvim_set_current_win(panel_state.input_win)
      if M.config.auto_input then
        vim.cmd("startinsert!")
      end
      return
    end
  end
  
  -- Check if we're in editor and trying to navigate to panel
  if direction == "right" and M.config.position == "right" and panel_state.is_open then
    M.focus_input()
    return
  elseif direction == "left" and M.config.position == "left" and panel_state.is_open then
    M.focus_input()
    return
  end
  
  -- Default window navigation
  vim.cmd("wincmd " .. direction:sub(1,1))
end

-- Focus management functions
function M.focus_input()
  if panel_state.input_win and vim.api.nvim_win_is_valid(panel_state.input_win) then
    vim.api.nvim_set_current_win(panel_state.input_win)
    panel_state.focus_mode = "input"
    if M.config.auto_input then
      vim.cmd("startinsert!")
    end
  end
end

function M.focus_panel()
  if panel_state.main_win and vim.api.nvim_win_is_valid(panel_state.main_win) then
    vim.api.nvim_set_current_win(panel_state.main_win)
    panel_state.focus_mode = "panel"
  end
end

-- Handle auto-focus on panel open
function M.handle_auto_focus()
  local function do_focus()
    if M.config.navigation.focus_on_open == "input" then
      M.focus_input()
    elseif M.config.navigation.focus_on_open == "panel" then
      M.focus_panel()
    elseif M.config.navigation.focus_on_open == "previous" then
      -- Stay in previous window
      if panel_state.previous_win and vim.api.nvim_win_is_valid(panel_state.previous_win) then
        vim.api.nvim_set_current_win(panel_state.previous_win)
      end
    end
  end
  
  if vim.schedule then
    vim.schedule(do_focus)
  else
    do_focus()
  end
end

-- Adjust main editor layout
function M.adjust_main_layout()
  if M.config.smart_resize then
    local available_width = vim.o.columns - M.config.width - 2
    if M.config.position == "right" then
      vim.cmd("vertical resize " .. available_width)
    else
      vim.cmd("wincmd l | vertical resize " .. available_width)
    end
  end
end

-- Opening animation
function M.start_opening_animation()
  if not M.config.modern_ui.animations then
    return
  end
  
  -- Simple fade-in effect by updating title
  local frames = {"▱", "▲", "▰", "▲"}
  local frame = 1
  
  panel_state.animation_timer = vim.loop.new_timer()
  panel_state.animation_timer:start(0, 150, vim.schedule_wrap(function()
    if not panel_state.is_open then
      if panel_state.animation_timer then
        panel_state.animation_timer:stop()
        panel_state.animation_timer:close()
        panel_state.animation_timer = nil
      end
      return
    end
    
    frame = frame % #frames + 1
    
    -- Update title with animation
    if panel_state.main_win and vim.api.nvim_win_is_valid(panel_state.main_win) then
      local title = frames[frame] .. " Claude Chat "
      vim.api.nvim_win_set_config(panel_state.main_win, {
        title = title,
      })
    end
    
    -- Stop animation after a few cycles
    if frame > 12 then
      if panel_state.animation_timer then
        panel_state.animation_timer:stop()
        panel_state.animation_timer:close()
        panel_state.animation_timer = nil
      end
      -- Reset to normal title
      if panel_state.main_win and vim.api.nvim_win_is_valid(panel_state.main_win) then
        vim.api.nvim_win_set_config(panel_state.main_win, {
          title = M.get_panel_title(),
        })
      end
    end
  end))
end

-- Close the modern chat panel
function M.close()
  if not panel_state.is_open then
    return
  end
  
  -- Stop animations
  if panel_state.animation_timer then
    panel_state.animation_timer:stop()
    panel_state.animation_timer:close()
    panel_state.animation_timer = nil
  end
  
  -- Close windows
  if panel_state.main_win and vim.api.nvim_win_is_valid(panel_state.main_win) then
    vim.api.nvim_win_close(panel_state.main_win, true)
  end
  
  if panel_state.input_win and vim.api.nvim_win_is_valid(panel_state.input_win) then
    vim.api.nvim_win_close(panel_state.input_win, true)
  end
  
  -- Clean up buffers (keep for session continuity)
  panel_state.is_open = false
  panel_state.main_win = nil
  panel_state.input_win = nil
  
  -- Restore main window layout
  vim.cmd("wincmd =")
  
  -- Return focus to previous window
  if panel_state.previous_win and vim.api.nvim_win_is_valid(panel_state.previous_win) then
    vim.api.nvim_set_current_win(panel_state.previous_win)
  end
end

-- Setup input keymaps for the persistent input buffer
function M.setup_input_keymaps(buf)
  local opts = { buffer = buf, silent = true, noremap = true }
  
  -- Send message on Enter (both normal and insert mode)
  vim.keymap.set("i", "<CR>", function()
    M.send_message()
  end, opts)
  
  vim.keymap.set("n", "<CR>", function()
    M.send_message()
  end, opts)
  
  -- Close panel on Escape
  vim.keymap.set({"i", "n"}, "<Esc>", function()
    M.close()
  end, opts)
  
  -- Input history navigation
  vim.keymap.set("i", "<Up>", function()
    M.navigate_input_history(-1)
  end, opts)
  
  vim.keymap.set("i", "<Down>", function()
    M.navigate_input_history(1)
  end, opts)
  
  -- Clear current input
  vim.keymap.set("i", "<C-u>", function()
    M.clear_input()
  end, opts)
  
  -- Tab completion (future enhancement)
  vim.keymap.set("i", "<Tab>", function()
    -- Could add command completion here
    return "<Tab>"
  end, { buffer = buf, expr = true })
end

-- Setup main panel keymaps  
function M.setup_main_panel_keymaps()
  if not panel_state.main_buf then return end
  
  local opts = { buffer = panel_state.main_buf, silent = true, noremap = true }
  
  -- Toggle panel
  vim.keymap.set("n", M.config.keymaps.toggle, M.toggle, opts)
  vim.keymap.set("n", "q", M.close, opts)
  
  -- Clear history
  vim.keymap.set("n", M.config.keymaps.clear_history, M.clear_history, opts)
  
  -- Refresh display
  vim.keymap.set("n", "r", M.refresh_display, opts)
  
  -- Context actions
  vim.keymap.set("n", "c", M.update_context, opts)
  
  -- Scroll to bottom
  vim.keymap.set("n", "G", function()
    M.scroll_to_bottom()
  end, opts)
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
    if win ~= panel_state.main_win and win ~= panel_state.input_win then
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

-- Helper: pad or truncate text to fit within a box row
-- content_w is the window's content width (M.config.width)
-- Row format: "│ <text> │" where the whole line is content_w display columns
local function box_row(text, content_w)
  -- "│ " = 2 display cols, " │" = 2 display cols => 4 cols of chrome
  local available = content_w - 4
  local display_len = vim.fn.strdisplaywidth(text)
  if display_len > available then
    -- Truncate to fit (byte-level trim, then add ellipsis)
    while vim.fn.strdisplaywidth(text) > available - 1 and #text > 0 do
      text = text:sub(1, #text - 1)
    end
    text = text .. "…"
    display_len = vim.fn.strdisplaywidth(text)
  end
  local pad = math.max(0, available - display_len)
  return "│ " .. text .. string.rep(" ", pad) .. " │"
end

-- Helper: create a horizontal rule like "╭── Title ──╮"
-- Total display width = content_w
local function box_rule(left, right, content_w, title)
  -- left + right corners = 2 display cols, fill the rest with "─"
  local fill_w = content_w - 2
  if title then
    local title_w = vim.fn.strdisplaywidth(title)
    local left_fill = 2
    -- " title " adds title_w + 2 display cols (spaces around title)
    local right_fill = math.max(0, fill_w - left_fill - title_w - 2)
    return left .. string.rep("─", left_fill) .. " " .. title .. " " .. string.rep("─", right_fill) .. right
  end
  return left .. string.rep("─", fill_w) .. right
end

-- Helper: create a message divider "┌─ label ────…"
-- Total display width = content_w
local function msg_header(label, content_w)
  local prefix = "┌─ " .. label .. " "
  local prefix_w = vim.fn.strdisplaywidth(prefix)
  local remaining = math.max(0, content_w - prefix_w)
  return prefix .. string.rep("─", remaining)
end

local function msg_footer(content_w)
  return "└" .. string.rep("─", content_w - 1)
end

-- Modern chat display with enhanced UI
function M.refresh_display()
  if not panel_state.is_open or not panel_state.main_buf or not vim.api.nvim_buf_is_valid(panel_state.main_buf) then
    return
  end

  -- Use the actual panel content width for all box-drawing
  local inner_w = M.config.width
  local lines = {}
  local icons = M.config.modern_ui.icons

  -- Header
  table.insert(lines, box_rule("╭", "╮", inner_w, icons.claude .. " Claude Chat"))

  -- Status line
  local status = panel_state.loading and "Processing..." or "Ready"
  local history_count = #panel_state.chat_history
  table.insert(lines, box_row("Status: " .. status, inner_w))
  table.insert(lines, box_row("Messages: " .. tostring(history_count), inner_w))

  -- Context info
  if M.config.show_context_info and panel_state.current_context then
    local ctx = panel_state.current_context
    local filename = ctx.filename and vim.fn.fnamemodify(ctx.filename, ":t") or "No file"
    local filetype = ctx.filetype or "unknown"
    local ft_suffix = ctx.selection and " (selected)" or ""

    table.insert(lines, box_rule("├", "┤", inner_w, "Context"))
    table.insert(lines, box_row(filename, inner_w))
    table.insert(lines, box_row(filetype .. ft_suffix, inner_w))
  end

  -- Controls
  table.insert(lines, box_rule("├", "┤", inner_w, "Controls"))
  table.insert(lines, box_row("Enter - Send    Esc - Close", inner_w))
  table.insert(lines, box_row("Up/Down - History   Ctrl+U - Clear", inner_w))
  table.insert(lines, box_rule("╰", "╯", inner_w))
  table.insert(lines, "")

  -- Chat history
  if #panel_state.chat_history > 0 then
    for _, entry in ipairs(panel_state.chat_history) do
      local timestamp = os.date("%H:%M", entry.timestamp or os.time())

      -- User message
      table.insert(lines, msg_header(icons.user .. " You (" .. timestamp .. ")", inner_w))
      local user_lines = vim.split(entry.user_message, "\n", { plain = true })
      for _, line in ipairs(user_lines) do
        table.insert(lines, "│ " .. line)
      end
      table.insert(lines, msg_footer(inner_w))
      table.insert(lines, "")

      -- Claude response
      if entry.loading then
        table.insert(lines, msg_header(icons.loading .. " Claude (thinking...)", inner_w))
        table.insert(lines, "│ " .. M.get_loading_animation())
      elseif entry.error then
        table.insert(lines, msg_header(icons.error .. " Claude (error)", inner_w))
        table.insert(lines, "│ " .. entry.error)
      else
        table.insert(lines, msg_header(icons.claude .. " Claude (" .. timestamp .. ")", inner_w))
        if entry.response then
          local response_lines = vim.split(entry.response, "\n", { plain = true })
          for _, line in ipairs(response_lines) do
            table.insert(lines, "│ " .. line)
          end
        end
      end
      table.insert(lines, msg_footer(inner_w))
      table.insert(lines, "")
    end
  else
    -- Welcome message
    table.insert(lines, box_rule("╭", "╮", inner_w, "Welcome"))
    table.insert(lines, box_row("", inner_w))
    table.insert(lines, box_row("Start typing in the input", inner_w))
    table.insert(lines, box_row("area below to chat with", inner_w))
    table.insert(lines, box_row("Claude about your code!", inner_w))
    table.insert(lines, box_row("", inner_w))
    table.insert(lines, box_rule("╰", "╯", inner_w))
    table.insert(lines, "")
  end
  
  -- Update buffer with syntax highlighting
  vim.api.nvim_buf_set_option(panel_state.main_buf, "modifiable", true)
  vim.api.nvim_buf_set_lines(panel_state.main_buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(panel_state.main_buf, "modifiable", false)
  
  -- Apply syntax highlighting if enabled
  if M.config.modern_ui.enabled then
    M.apply_syntax_highlighting()
  end
  
  -- Auto-scroll to bottom
  M.scroll_to_bottom()
end

-- Loading animation frames
local loading_frames = {"●○○", "○●○", "○○●", "○●○"}
local loading_frame_index = 1

function M.get_loading_animation()
  loading_frame_index = loading_frame_index % #loading_frames + 1
  return loading_frames[loading_frame_index] .. " Processing your request..."
end

-- Apply modern syntax highlighting
function M.apply_syntax_highlighting()
  if not panel_state.main_buf or not vim.api.nvim_buf_is_valid(panel_state.main_buf) then
    return
  end
  
  -- Check if namespace functions are available (for compatibility)
  if not vim.api.nvim_create_namespace then
    return
  end
  
  local ns = vim.api.nvim_create_namespace("claude_chat_hl")
  if vim.api.nvim_buf_clear_namespace then
    vim.api.nvim_buf_clear_namespace(panel_state.main_buf, ns, 0, -1)
  end
  
  local lines = vim.api.nvim_buf_get_lines(panel_state.main_buf, 0, -1, false)
  
  for i, line in ipairs(lines) do
    local line_num = i - 1

    -- Only apply highlighting if the function is available
    if vim.api.nvim_buf_add_highlight then
      -- Highlight box borders and rules (top, bottom, dividers, footers)
      if line:match("^[╭├╰┌└│].*[╮┤╯┐┘│]$") or line:match("^[└╰]─") then
        vim.api.nvim_buf_add_highlight(panel_state.main_buf, ns, M.config.modern_ui.colors.border, line_num, 0, -1)

      -- Highlight user message headers
      elseif line:match("^┌.*" .. M.config.modern_ui.icons.user) then
        vim.api.nvim_buf_add_highlight(panel_state.main_buf, ns, M.config.modern_ui.colors.user_message, line_num, 0, -1)

      -- Highlight Claude message headers
      elseif line:match("^┌.*" .. M.config.modern_ui.icons.claude) then
        vim.api.nvim_buf_add_highlight(panel_state.main_buf, ns, M.config.modern_ui.colors.claude_message, line_num, 0, -1)

      -- Highlight loading messages
      elseif line:match(M.config.modern_ui.icons.loading) then
        vim.api.nvim_buf_add_highlight(panel_state.main_buf, ns, M.config.modern_ui.colors.loading, line_num, 0, -1)

      -- Highlight error messages
      elseif line:match(M.config.modern_ui.icons.error) then
        vim.api.nvim_buf_add_highlight(panel_state.main_buf, ns, M.config.modern_ui.colors.error, line_num, 0, -1)
      end
    end
  end
end

-- Utility function to scroll to bottom
function M.scroll_to_bottom()
  if panel_state.main_win and vim.api.nvim_win_is_valid(panel_state.main_win) then
    -- Use fallback if nvim_buf_line_count is not available
    local line_count
    if vim.api.nvim_buf_line_count then
      line_count = vim.api.nvim_buf_line_count(panel_state.main_buf)
    else
      local lines = vim.api.nvim_buf_get_lines(panel_state.main_buf, 0, -1, false)
      line_count = #lines
    end
    vim.api.nvim_win_set_cursor(panel_state.main_win, {line_count, 0})
  end
end

-- Input history navigation
function M.navigate_input_history(direction)
  if #panel_state.input_history == 0 then
    return
  end
  
  if direction < 0 then -- Up arrow - go back in history
    panel_state.input_history_pos = math.max(1, panel_state.input_history_pos - 1)
  else -- Down arrow - go forward in history
    panel_state.input_history_pos = math.min(#panel_state.input_history + 1, panel_state.input_history_pos + 1)
  end
  
  -- Set the input buffer content
  if panel_state.input_buf and vim.api.nvim_buf_is_valid(panel_state.input_buf) then
    local content = ""
    if panel_state.input_history_pos <= #panel_state.input_history then
      content = panel_state.input_history[panel_state.input_history_pos]
    end
    
    vim.api.nvim_buf_set_lines(panel_state.input_buf, 0, -1, false, {content})
    vim.cmd("startinsert!")
  end
end

-- Clear current input
function M.clear_input()
  if panel_state.input_buf and vim.api.nvim_buf_is_valid(panel_state.input_buf) then
    vim.api.nvim_buf_set_lines(panel_state.input_buf, 0, -1, false, {""})
  end
end

-- Send message to Claude
function M.send_message()
  if not panel_state.input_buf or not vim.api.nvim_buf_is_valid(panel_state.input_buf) then
    return
  end
  
  -- Get message from input buffer
  local lines = vim.api.nvim_buf_get_lines(panel_state.input_buf, 0, -1, false)
  local message = utils.string.trim(table.concat(lines, "\n"))
  
  -- Remove the prompt prefix if it exists
  local prompt_prefix = M.config.modern_ui.icons.input .. " "
  if message:sub(1, #prompt_prefix) == prompt_prefix then
    message = message:sub(#prompt_prefix + 1)
  end
  
  if message == "" then
    return
  end
  
  -- Add to input history
  table.insert(panel_state.input_history, message)
  if #panel_state.input_history > 50 then -- Limit history size
    table.remove(panel_state.input_history, 1)
  end
  panel_state.input_history_pos = #panel_state.input_history + 1
  
  -- Clear input
  M.clear_input()
  
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
  
  -- Update loading state
  panel_state.loading = true
  
  -- Refresh display with loading indicator
  M.refresh_display()
  
  -- Update window title to show loading
  if panel_state.main_win and vim.api.nvim_win_is_valid(panel_state.main_win) then
    vim.api.nvim_win_set_config(panel_state.main_win, {
      title = M.get_panel_title(),
    })
  end
  
  -- Update context before sending
  M.update_context()
  
  -- Check API status
  local api_status = M.check_api_status()
  if not api_status.available then
    local last_entry = panel_state.chat_history[#panel_state.chat_history]
    if last_entry then
      last_entry.loading = false
      last_entry.error = "API not available: " .. api_status.status
    end
    panel_state.loading = false
    M.refresh_display()
    vim.notify("Claude Code Chat: " .. api_status.status, vim.log.levels.ERROR)
    return
  end
  
  -- Send to Claude API with enhanced callback
  local success, result = pcall(function()
    return api.request(message, panel_state.current_context, function(response, error)
      panel_state.loading = false
      
      -- Update the last entry
      local last_entry = panel_state.chat_history[#panel_state.chat_history]
      if last_entry then
        last_entry.loading = false
        if error then
          last_entry.error = tostring(error)
          vim.notify("Claude Code Chat: " .. tostring(error), vim.log.levels.ERROR)
        elseif response then
          last_entry.response = tostring(response)
          -- Show success notification for first message
          if #panel_state.chat_history == 1 and M.config.modern_ui.enabled then
            vim.notify(M.config.modern_ui.icons.success .. " Response received!", vim.log.levels.INFO)
          end
        else
          last_entry.error = "Empty response from API"
          vim.notify("Claude Code Chat: Received empty response", vim.log.levels.WARN)
        end
      end
      
      -- Update window title
      if panel_state.main_win and vim.api.nvim_win_is_valid(panel_state.main_win) then
        vim.api.nvim_win_set_config(panel_state.main_win, {
          title = M.get_panel_title(),
        })
      end
      
      -- Refresh display
      M.refresh_display()
      
      -- Auto-focus input for next message if enabled
      if M.config.auto_input and M.config.navigation.focus_on_open == "input" then
        local function focus_input()
          M.focus_input()
        end
        
        if vim.schedule then
          vim.schedule(focus_input)
        else
          focus_input()
        end
      end
    end)
  end)
  
  if not success then
    panel_state.loading = false
    local last_entry = panel_state.chat_history[#panel_state.chat_history]
    if last_entry then
      last_entry.loading = false
      last_entry.error = "API call failed: " .. tostring(result)
    end
    M.refresh_display()
    vim.notify("Claude Code Chat: Failed to call API - " .. tostring(result), vim.log.levels.ERROR)
    return
  end
  
  if not result then
    panel_state.loading = false
    local last_entry = panel_state.chat_history[#panel_state.chat_history]
    if last_entry then
      last_entry.loading = false
      last_entry.error = "Failed to start request"
    end
    M.refresh_display()
    vim.notify("Claude Code Chat: Failed to initiate request", vim.log.levels.ERROR)
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

-- Check API configuration status
function M.check_api_status()
  local status = api.check_auth_status()
  return status
end

-- Show API status in chat panel
function M.show_api_status()
  local status = M.check_api_status()
  local message = "API Status: " .. status.status
  
  if status.method == "cli" then
    message = message .. " (using Claude CLI)"
  elseif status.method == "api" then
    message = message .. " (using HTTP API)"
  end
  
  vim.notify("Claude Code: " .. message, status.available and vim.log.levels.INFO or vim.log.levels.WARN)
  return status.available
end

-- Clean up existing buffers to prevent duplicates
function M.cleanup_buffers()
  -- Clean up main buffer if it exists but is not being used
  if panel_state.main_buf and vim.api.nvim_buf_is_valid(panel_state.main_buf) then
    if not panel_state.is_open then
      vim.api.nvim_buf_delete(panel_state.main_buf, { force = true })
      panel_state.main_buf = nil
    end
  end
  
  -- Clean up input buffer if it exists but is not being used
  if panel_state.input_buf and vim.api.nvim_buf_is_valid(panel_state.input_buf) then
    if not panel_state.is_open then
      vim.api.nvim_buf_delete(panel_state.input_buf, { force = true })
      panel_state.input_buf = nil
    end
  end
end

-- Enhanced cleanup function
function M.cleanup()
  -- Stop animations
  if panel_state.animation_timer then
    panel_state.animation_timer:stop()
    panel_state.animation_timer:close()
    panel_state.animation_timer = nil
  end
  
  if panel_state.is_open then
    M.close()
  end
  
  -- Clean up buffers
  if panel_state.main_buf and vim.api.nvim_buf_is_valid(panel_state.main_buf) then
    vim.api.nvim_buf_delete(panel_state.main_buf, { force = true })
  end
  
  if panel_state.input_buf and vim.api.nvim_buf_is_valid(panel_state.input_buf) then
    vim.api.nvim_buf_delete(panel_state.input_buf, { force = true })
  end
  
  -- Reset enhanced state
  panel_state = {
    is_open = false,
    main_win = nil,
    main_buf = nil,
    input_win = nil,
    input_buf = nil,
    chat_history = {},
    current_context = nil,
    loading = false,
    previous_win = nil,
    input_history = {},
    input_history_pos = 0,
    animation_timer = nil,
    focus_mode = "input",
  }
end

-- Updated setup function call
function M.setup_after_open()
  -- Setup main panel keymaps
  M.setup_main_panel_keymaps()
  
  -- Setup autocommands if not already done
  if not M.autocommands_setup then
    M.setup_autocommands()
    M.autocommands_setup = true
  end
end

return M