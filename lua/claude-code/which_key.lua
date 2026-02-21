-- Which-key integration for Claude Code Neovim Plugin
-- Provides hierarchical command structure and descriptive menus
local config = require("claude-code.config")

local M = {}

-- Internal state
local which_key_state = {
  enabled = false,
  which_key_available = false,
  registered_mappings = {},
}

-- Default which-key configuration
local which_key_defaults = {
  enabled = true,
  auto_register = true,
  prefix = "<leader>c", -- Main Claude Code prefix
  terminal_prefix = "<leader>ct", -- Terminal-specific prefix
  git_prefix = "<leader>cg", -- Git-specific prefix
  file_prefix = "<leader>cf", -- File operations prefix
  show_icons = true,
  show_help = true,
  timeout = 300, -- ms before which-key popup appears
  layout = {
    width = { min = 20, max = 50 },
    height = { min = 4, max = 25 },
    spacing = 3,
  },
}

-- Initialize which-key integration
function M.setup(user_config)
  local cfg = vim.tbl_deep_extend("force", which_key_defaults, user_config or {})
  config.update({ which_key = cfg })
  
  if cfg.enabled then
    which_key_state.enabled = true
    
    -- Check if which-key is available
    local ok, wk = pcall(require, "which-key")
    if ok then
      which_key_state.which_key_available = true
      
      if cfg.auto_register then
        M.register_mappings()
      end
    else
      vim.notify("which-key.nvim not found - Claude Code will work without it", vim.log.levels.INFO)
    end
  end
end

-- Register all Claude Code mappings with which-key
function M.register_mappings()
  if not which_key_state.which_key_available then
    return
  end
  
  local wk = require("which-key")
  local cfg = config.get().which_key
  
  -- Main Claude Code mappings
  local main_mappings = M.get_main_mappings(cfg)
  if main_mappings then
    wk.register(main_mappings, { prefix = cfg.prefix })
    which_key_state.registered_mappings["main"] = main_mappings
  end
  
  -- Terminal mappings
  local terminal_mappings = M.get_terminal_mappings(cfg)
  if terminal_mappings then
    wk.register(terminal_mappings, { prefix = cfg.terminal_prefix })
    which_key_state.registered_mappings["terminal"] = terminal_mappings
  end
  
  -- Git mappings
  local git_mappings = M.get_git_mappings(cfg)
  if git_mappings then
    wk.register(git_mappings, { prefix = cfg.git_prefix })
    which_key_state.registered_mappings["git"] = git_mappings
  end
  
  -- File operations mappings
  local file_mappings = M.get_file_mappings(cfg)
  if file_mappings then
    wk.register(file_mappings, { prefix = cfg.file_prefix })
    which_key_state.registered_mappings["file"] = file_mappings
  end
  
  vim.notify("Claude Code which-key mappings registered", vim.log.levels.INFO)
end

-- Get main Claude Code mappings
function M.get_main_mappings(cfg)
  local icons = cfg.show_icons
  
  return {
    name = icons and "🤖 Claude Code" or "Claude Code",
    
    -- Code writing
    w = { ":ClaudeWriteFunction<CR>", icons and "✍️  Write Function" or "Write Function" },
    i = { ":ClaudeImplementTodo<CR>", icons and "📝 Implement TODO" or "Implement TODO" },
    e = { ":ClaudeExplainCode<CR>", icons and "📖 Explain Code" or "Explain Code" },
    
    -- Debugging
    d = { ":ClaudeDebugError<CR>", icons and "🐛 Debug Error" or "Debug Error" },
    s = { ":ClaudeAnalyzeStack<CR>", icons and "📊 Analyze Stack" or "Analyze Stack" },
    x = { ":ClaudeSuggestFix<CR>", icons and "🔧 Suggest Fix" or "Suggest Fix" },
    
    -- Code review
    r = {
      name = icons and "🔍 Review" or "Review",
      r = { ":ClaudeReviewCode<CR>", icons and "📋 Review Code" or "Review Code" },
      f = { ":ClaudeReviewFile<CR>", icons and "📄 Review File" or "Review File" },
      s = { ":ClaudeSecurityCheck<CR>", icons and "🛡️  Security Check" or "Security Check" },
    },
    
    -- Testing
    t = {
      name = icons and "🧪 Testing" or "Testing",
      t = { ":ClaudeGenerateTests<CR>", icons and "⚗️  Generate Tests" or "Generate Tests" },
      m = { ":ClaudeGenerateMocks<CR>", icons and "🎭 Generate Mocks" or "Generate Mocks" },
      c = { ":ClaudeTestCoverage<CR>", icons and "📈 Test Coverage" or "Test Coverage" },
    },
    
    -- Refactoring
    R = {
      name = icons and "♻️  Refactor" or "Refactor",
      e = { ":ClaudeRefactorExtract<CR>", icons and "📤 Extract" or "Extract Method/Class" },
      o = { ":ClaudeRefactorOptimize<CR>", icons and "⚡ Optimize" or "Optimize Code" },
      r = { ":ClaudeRefactorRename<CR>", icons and "🏷️  Rename" or "Intelligent Rename" },
    },
    
    -- General
    c = { ":ClaudeChat<CR>", icons and "💬 Chat" or "Open Chat" },
    h = { ":ClaudeHelp<CR>", icons and "❓ Help" or "Show Help" },
    S = { ":ClaudeStatus<CR>", icons and "📊 Status" or "Show Status" },
    
    -- Terminal (quick access)
    ["`"] = { ":ClaudeTerminalToggle<CR>", icons and "🚀 Terminal" or "Toggle Terminal" },
  }
end

-- Get terminal-specific mappings
function M.get_terminal_mappings(cfg)
  local icons = cfg.show_icons
  
  return {
    name = icons and "🚀 Claude Terminal" or "Claude Terminal",
    
    t = { ":ClaudeTerminal<CR>", icons and "📺 Open Terminal" or "Open Terminal" },
    T = { ":ClaudeTerminalToggle<CR>", icons and "🔄 Toggle Terminal" or "Toggle Terminal" },
    c = { ":ClaudeTerminalContinue<CR>", icons and "▶️  Continue Session" or "Continue Session" },
    x = { ":ClaudeTerminalClear<CR>", icons and "🧹 Clear Session" or "Clear Session" },
  }
end

-- Get git-specific mappings  
function M.get_git_mappings(cfg)
  local icons = cfg.show_icons
  
  return {
    name = icons and "🌿 Git Integration" or "Git Integration",
    
    s = { ":ClaudeGitStatus<CR>", icons and "📊 Git Status" or "Show Git Status" },
    c = { ":ClaudeGitContext<CR>", icons and "📋 Git Context" or "Show Git Context" },
    r = { ":ClaudeGitRoot<CR>", icons and "📁 Git Root" or "Go to Git Root" },
    x = { ":ClaudeGitClearCache<CR>", icons and "🧹 Clear Cache" or "Clear Git Cache" },
  }
end

-- Get file operations mappings
function M.get_file_mappings(cfg)
  local icons = cfg.show_icons
  
  return {
    name = icons and "📁 File Operations" or "File Operations",
    
    w = {
      name = icons and "👁️  File Watcher" or "File Watcher",
      t = { ":ClaudeFileWatchToggle<CR>", icons and "🔄 Toggle Watcher" or "Toggle File Watching" },
      r = { ":ClaudeFileWatchReload<CR>", icons and "🔄 Reload Files" or "Reload All Files" },
      s = { ":ClaudeFileWatchStatus<CR>", icons and "📊 Watcher Status" or "Show Watcher Status" },
      c = { ":ClaudeFileWatchClear<CR>", icons and "🧹 Clear Cache" or "Clear Watcher Cache" },
    },
  }
end

-- Register custom mapping group
function M.register_custom_group(prefix, mappings, opts)
  if not which_key_state.which_key_available then
    return false
  end
  
  local wk = require("which-key")
  opts = opts or {}
  opts.prefix = prefix
  
  wk.register(mappings, opts)
  
  -- Store for cleanup
  which_key_state.registered_mappings[prefix] = mappings
  
  return true
end

-- Unregister mapping group
function M.unregister_group(prefix)
  if not which_key_state.which_key_available then
    return false
  end
  
  -- which-key doesn't have a direct unregister method,
  -- so we'll just remove from our tracking
  which_key_state.registered_mappings[prefix] = nil
  
  return true
end

-- Update mappings based on feature availability
function M.update_mappings_for_features()
  if not which_key_state.which_key_available or not which_key_state.enabled then
    return
  end
  
  local cfg = config.get()
  
  -- Check which features are enabled and update mappings accordingly
  local features_enabled = {
    terminal = cfg.terminal and cfg.terminal.enabled,
    git = cfg.git and cfg.git.enabled,
    file_watcher = cfg.file_watcher and cfg.file_watcher.enabled,
  }
  
  -- Re-register mappings based on enabled features
  if features_enabled.terminal then
    local terminal_mappings = M.get_terminal_mappings(cfg.which_key)
    if terminal_mappings then
      require("which-key").register(terminal_mappings, { prefix = cfg.which_key.terminal_prefix })
    end
  end
  
  if features_enabled.git then
    local git_mappings = M.get_git_mappings(cfg.which_key)
    if git_mappings then
      require("which-key").register(git_mappings, { prefix = cfg.which_key.git_prefix })
    end
  end
  
  if features_enabled.file_watcher then
    local file_mappings = M.get_file_mappings(cfg.which_key)
    if file_mappings then
      require("which-key").register(file_mappings, { prefix = cfg.which_key.file_prefix })
    end
  end
end

-- Get visual mode mappings (for selected text operations)
function M.get_visual_mappings(cfg)
  local icons = cfg.show_icons
  
  return {
    [cfg.prefix] = {
      name = icons and "🤖 Claude Code" or "Claude Code",
      
      e = { ":ClaudeExplainCode<CR>", icons and "📖 Explain Selection" or "Explain Selection" },
      r = { ":ClaudeReviewCode<CR>", icons and "🔍 Review Selection" or "Review Selection" },
      t = { ":ClaudeGenerateTests<CR>", icons and "🧪 Generate Tests" or "Generate Tests" },
      x = { ":ClaudeSuggestFix<CR>", icons and "🔧 Suggest Fix" or "Suggest Fix" },
      
      R = {
        name = icons and "♻️  Refactor" or "Refactor",
        e = { ":ClaudeRefactorExtract<CR>", icons and "📤 Extract Selection" or "Extract Selection" },
        o = { ":ClaudeRefactorOptimize<CR>", icons and "⚡ Optimize Selection" or "Optimize Selection" },
      },
    }
  }
end

-- Register visual mode mappings
function M.register_visual_mappings()
  if not which_key_state.which_key_available then
    return
  end
  
  local cfg = config.get().which_key
  local visual_mappings = M.get_visual_mappings(cfg)
  
  require("which-key").register(visual_mappings, { mode = "v" })
  which_key_state.registered_mappings["visual"] = visual_mappings
end

-- Show help for specific command group
function M.show_group_help(group_name)
  if not which_key_state.which_key_available then
    vim.notify("which-key.nvim is required for interactive help", vim.log.levels.WARN)
    return
  end
  
  local cfg = config.get().which_key
  local prefix = ""
  
  if group_name == "main" then
    prefix = cfg.prefix
  elseif group_name == "terminal" then
    prefix = cfg.terminal_prefix
  elseif group_name == "git" then
    prefix = cfg.git_prefix
  elseif group_name == "file" then
    prefix = cfg.file_prefix
  else
    vim.notify("Unknown command group: " .. group_name, vim.log.levels.WARN)
    return
  end
  
  -- Trigger which-key popup for the specific prefix
  local keys = vim.api.nvim_replace_termcodes(prefix, true, false, true)
  vim.api.nvim_feedkeys(keys, "n", true)
end

-- Get command completion for which-key groups
function M.get_group_completion()
  return { "main", "terminal", "git", "file", "visual" }
end

-- Setup which-key specific commands
function M.setup_commands()
  -- Show specific group help
  vim.api.nvim_create_user_command("ClaudeWhichKeyHelp", function(opts)
    local group = opts.args and opts.args ~= "" and opts.args or "main"
    M.show_group_help(group)
  end, {
    desc = "Show which-key help for Claude Code groups",
    nargs = "?",
    complete = function()
      return M.get_group_completion()
    end,
  })
  
  -- Re-register all mappings
  vim.api.nvim_create_user_command("ClaudeWhichKeyRegister", function()
    M.register_mappings()
  end, {
    desc = "Re-register Claude Code which-key mappings",
  })
  
  -- Show which-key status
  vim.api.nvim_create_user_command("ClaudeWhichKeyStatus", function()
    M.show_which_key_status()
  end, {
    desc = "Show which-key integration status",
  })
end

-- Show which-key integration status
function M.show_which_key_status()
  local status_lines = {
    "Claude Code Which-key Integration Status",
    "=======================================",
    "",
    "Enabled: " .. (which_key_state.enabled and "✅ Yes" or "❌ No"),
    "Which-key Available: " .. (which_key_state.which_key_available and "✅ Yes" or "❌ No"),
    "",
    "Registered Groups: " .. vim.tbl_count(which_key_state.registered_mappings),
    "",
  }
  
  if vim.tbl_count(which_key_state.registered_mappings) > 0 then
    table.insert(status_lines, "Active Groups:")
    for group_name, _ in pairs(which_key_state.registered_mappings) do
      table.insert(status_lines, "  • " .. group_name)
    end
    table.insert(status_lines, "")
    
    local cfg = config.get().which_key
    table.insert(status_lines, "Key Prefixes:")
    table.insert(status_lines, "  • Main: " .. cfg.prefix)
    table.insert(status_lines, "  • Terminal: " .. cfg.terminal_prefix)  
    table.insert(status_lines, "  • Git: " .. cfg.git_prefix)
    table.insert(status_lines, "  • File: " .. cfg.file_prefix)
  else
    table.insert(status_lines, "No groups currently registered.")
  end
  
  require("claude-code.ui").show_response(status_lines, {
    title = "Which-key Status",
    filetype = "text",
  })
end

-- Create which-key configuration example
function M.get_config_example()
  return {
    which_key = {
      enabled = true,
      auto_register = true,
      prefix = "<leader>c",
      terminal_prefix = "<leader>ct",
      git_prefix = "<leader>cg", 
      file_prefix = "<leader>cf",
      show_icons = true,
      show_help = true,
      timeout = 300,
    }
  }
end

-- Check if which-key is available
function M.is_available()
  return which_key_state.which_key_available
end

-- Check if which-key integration is enabled
function M.is_enabled()
  return which_key_state.enabled
end

-- Get registered mappings
function M.get_registered_mappings()
  return which_key_state.registered_mappings
end

-- Force re-registration of all mappings
function M.force_reregister()
  if which_key_state.which_key_available and which_key_state.enabled then
    -- Clear existing registrations
    which_key_state.registered_mappings = {}
    
    -- Re-register everything
    M.register_mappings()
    M.register_visual_mappings()
    M.update_mappings_for_features()
    
    vim.notify("Claude Code which-key mappings re-registered", vim.log.levels.INFO)
  end
end

-- Cleanup function
function M.cleanup()
  -- Clear all registered mappings
  which_key_state.registered_mappings = {}
  
  -- Reset state
  which_key_state = {
    enabled = false,
    which_key_available = false,
    registered_mappings = {},
  }
end

return M