-- Claude Code Neovim Plugin
-- Enhanced main initialization with comprehensive module integration
local config = require("claude-code.config")
local api = require("claude-code.api")
local ui = require("claude-code.ui")

-- New enhanced modules
local terminal = require("claude-code.terminal")
local file_watcher = require("claude-code.file_watcher")
local git = require("claude-code.git")
local which_key = require("claude-code.which_key")
local chat_panel = require("claude-code.chat_panel")

local M = {}

-- Plugin state with enhanced tracking
M.initialized = false
M.modules_loaded = {}
M.startup_time = nil
M.version = "2.0.0"

-- Module loading order for proper dependency management
local MODULE_LOAD_ORDER = {
  "config",
  "git", 
  "file_watcher",
  "terminal",
  "chat_panel",
  "which_key",
  "api",
  "ui"
}

-- Enhanced setup function with module lifecycle management
function M.setup(user_config)
  if M.initialized then
    vim.notify("Claude Code already initialized", vim.log.levels.WARN)
    return
  end
  
  local start_time = vim.loop.hrtime()
  user_config = user_config or {}
  
  -- Phase 1: Configuration setup and validation
  M.init_configuration(user_config)
  
  -- Phase 2: Initialize modules in dependency order
  M.init_modules(user_config)
  
  -- Phase 3: Register commands and setup keybindings
  M.register_all_commands()
  
  -- Phase 4: Setup autocommands and integrations
  M.create_autocommands()
  
  -- Phase 5: Post-initialization setup
  M.finalize_setup()
  
  M.initialized = true
  M.startup_time = (vim.loop.hrtime() - start_time) / 1e6 -- Convert to milliseconds
  
  vim.notify(string.format("Claude Code v%s initialized in %.2fms", M.version, M.startup_time), vim.log.levels.INFO)
end

-- Phase 1: Configuration initialization
function M.init_configuration(user_config)
  -- Setup configuration with enhanced validation
  config.setup(user_config)
  config.setup_config_commands()
  M.modules_loaded.config = true
  
  -- Validate configuration
  local is_valid = config.validate()
  if not is_valid then
    vim.notify("Configuration validation failed. Some features may not work correctly.", vim.log.levels.WARN)
  end
end

-- Phase 2: Module initialization
function M.init_modules(user_config)
  local cfg = config.get()
  
  -- Initialize git integration first (provides context for other modules)
  if cfg.git and cfg.git.enabled then
    git.setup(user_config.git)
    M.modules_loaded.git = true
  end
  
  -- Initialize file watcher
  if cfg.file_watcher and cfg.file_watcher.enabled then
    file_watcher.setup(user_config.file_watcher)
    M.modules_loaded.file_watcher = true
  end
  
  -- Initialize terminal integration
  if cfg.terminal and cfg.terminal.enabled then
    terminal.setup(user_config.terminal)
    M.modules_loaded.terminal = true
  end
  
  -- Initialize chat panel
  if cfg.chat_panel and cfg.chat_panel.enabled then
    chat_panel.setup(user_config.chat_panel)
    M.modules_loaded.chat_panel = true
  end
  
  -- Initialize which-key integration (after terminal for key bindings)
  if cfg.which_key and cfg.which_key.enabled then
    which_key.setup(user_config.which_key)
    which_key.setup_commands()
    M.modules_loaded.which_key = true
  end
  
  -- API and UI are always initialized
  M.modules_loaded.api = true
  M.modules_loaded.ui = true
end

-- Phase 3: Enhanced command registration
function M.register_all_commands()
  -- Register core commands
  M.register_commands()
  
  -- Register module-specific commands if modules are loaded
  if M.modules_loaded.terminal then
    -- Terminal commands are registered in terminal.setup()
  end
  
  if M.modules_loaded.git then
    -- Git commands are registered in git.setup()
  end
  
  if M.modules_loaded.file_watcher then
    -- File watcher commands are registered in file_watcher.setup()
  end
end

-- Phase 5: Post-initialization finalization
function M.finalize_setup()
  -- Setup which-key mappings after all commands are registered
  if M.modules_loaded.which_key then
    which_key.register_mappings()
    which_key.register_visual_mappings()
    which_key.update_mappings_for_features()
  end
  
  -- Setup default keymaps
  config.setup_keymaps()
end

-- Register core Claude Code commands
function M.register_commands()
  -- Code writing commands
  vim.api.nvim_create_user_command("ClaudeWriteFunction", M.write_function, {
    desc = "Generate function from description using Claude Code",
    nargs = "?",
  })
  
  vim.api.nvim_create_user_command("ClaudeImplementTodo", M.implement_todo, {
    desc = "Implement TODO comment using Claude Code",
  })
  
  vim.api.nvim_create_user_command("ClaudeExplainCode", M.explain_code, {
    desc = "Explain code using Claude Code",
    range = true,
  })
  
  -- Debugging commands
  vim.api.nvim_create_user_command("ClaudeDebugError", M.debug_error, {
    desc = "Debug error using Claude Code",
    nargs = "?",
  })
  
  vim.api.nvim_create_user_command("ClaudeAnalyzeStack", M.analyze_stack_trace, {
    desc = "Analyze stack trace using Claude Code",
  })
  
  vim.api.nvim_create_user_command("ClaudeSuggestFix", M.suggest_fix, {
    desc = "Suggest fix for code issue using Claude Code",
    range = true,
  })
  
  -- Code review commands
  vim.api.nvim_create_user_command("ClaudeReviewCode", M.review_code, {
    desc = "Review code using Claude Code",
    range = true,
  })
  
  vim.api.nvim_create_user_command("ClaudeReviewFile", M.review_file, {
    desc = "Review entire file using Claude Code",
  })
  
  vim.api.nvim_create_user_command("ClaudeSecurityCheck", M.security_check, {
    desc = "Security vulnerability check using Claude Code",
    range = true,
  })
  
  -- Testing commands
  vim.api.nvim_create_user_command("ClaudeGenerateTests", M.generate_tests, {
    desc = "Generate tests using Claude Code",
    range = true,
  })
  
  vim.api.nvim_create_user_command("ClaudeGenerateMocks", M.generate_mocks, {
    desc = "Generate mock objects using Claude Code",
    range = true,
  })
  
  vim.api.nvim_create_user_command("ClaudeTestCoverage", M.test_coverage_analysis, {
    desc = "Test coverage analysis using Claude Code",
  })
  
  -- Refactoring commands
  vim.api.nvim_create_user_command("ClaudeRefactorExtract", M.refactor_extract, {
    desc = "Extract method/class using Claude Code",
    range = true,
  })
  
  vim.api.nvim_create_user_command("ClaudeRefactorOptimize", M.refactor_optimize, {
    desc = "Optimize code using Claude Code",
    range = true,
  })
  
  vim.api.nvim_create_user_command("ClaudeRefactorRename", M.refactor_rename, {
    desc = "Intelligent rename suggestions using Claude Code",
  })
  
  -- General commands
  vim.api.nvim_create_user_command("ClaudeChat", M.open_chat, {
    desc = "Open Claude Code chat",
  })
  
  vim.api.nvim_create_user_command("ClaudeHelp", M.show_help, {
    desc = "Show Claude Code help",
  })
  
  vim.api.nvim_create_user_command("ClaudeStatus", M.show_status, {
    desc = "Show Claude Code status",
  })
  
  -- Completion toggle
  vim.api.nvim_create_user_command("ClaudeToggleCompletion", M.toggle_completion, {
    desc = "Toggle Claude Code completion",
  })
end

-- Phase 4: Enhanced autocommands creation
function M.create_autocommands()
  local group = vim.api.nvim_create_augroup("ClaudeCode", { clear = true })
  
  -- Enhanced cleanup on exit with all modules
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = function()
      M.cleanup_all_modules()
    end,
  })
  
  -- Auto-completion setup (if enabled)
  if config.get().features.completion.enabled then
    -- Could integrate with completion engines here
  end
  
  -- Plugin health monitoring
  vim.api.nvim_create_autocmd("BufEnter", {
    group = group,
    pattern = "*",
    callback = function()
      -- Periodic health checks could go here
    end,
  })
end

-- Enhanced cleanup function for all modules
function M.cleanup_all_modules()
  -- Cleanup modules in reverse order
  if M.modules_loaded.which_key then
    which_key.cleanup()
  end
  
  if M.modules_loaded.chat_panel then
    chat_panel.cleanup()
  end
  
  if M.modules_loaded.terminal then
    terminal.cleanup()
  end
  
  if M.modules_loaded.file_watcher then
    file_watcher.cleanup()
  end
  
  if M.modules_loaded.git then
    git.cleanup()
  end
  
  -- Core cleanup
  ui.cleanup()
  api.cancel_requests()
  
  -- Reset state
  M.modules_loaded = {}
end

-- Command implementations

-- Write function from description
function M.write_function(opts)
  opts = opts or {}
  local description = opts.args
  
  if not description or description == "" then
    ui.input_dialog("Describe the function you want to create", function(input)
      if input then
        M._generate_code(input, "function")
      end
    end, { title = "Claude Code - Write Function" })
  else
    M._generate_code(description, "function")
  end
end

-- Implement TODO comment
function M.implement_todo()
  local context = ui.get_current_context()
  local cursor_line = vim.api.nvim_get_current_line()
  
  -- Look for TODO comment in current line or nearby lines
  local todo_pattern = "TODO:?%s*(.*)"
  local todo_match = cursor_line:match(todo_pattern)
  
  if not todo_match then
    -- Search nearby lines for TODO
    local buf = vim.api.nvim_get_current_buf()
    local cursor_row = vim.api.nvim_win_get_cursor(0)[1]
    
    for i = math.max(1, cursor_row - 5), math.min(vim.api.nvim_buf_line_count(buf), cursor_row + 5) do
      local line = vim.api.nvim_buf_get_lines(buf, i - 1, i, false)[1] or ""
      todo_match = line:match(todo_pattern)
      if todo_match then
        break
      end
    end
  end
  
  if todo_match and todo_match ~= "" then
    M._generate_code(todo_match, "todo", context)
  else
    ui.show_error("No TODO comment found near cursor")
  end
end

-- Explain code
function M.explain_code(opts)
  local context = ui.get_current_context()
  local code_to_explain = context.selection or context.file_content
  
  if not code_to_explain or code_to_explain:trim() == "" then
    ui.show_error("No code selected or file is empty")
    return
  end
  
  local loading_win = ui.show_loading("Claude Code", "Analyzing code...")
  
  api.explain_code(code_to_explain, context, function(response, error)
    if error then
      ui.show_error(error, { loading_win = loading_win })
    else
      ui.show_response(response, {
        title = "Claude Code - Code Explanation",
        loading_win = loading_win,
      })
    end
  end)
end

-- Debug error
function M.debug_error(opts)
  local error_message = opts.args
  
  if not error_message or error_message == "" then
    -- Try to get error from quickfix or location list
    local qflist = vim.fn.getqflist()
    if #qflist > 0 then
      local current_error = qflist[1]
      error_message = current_error.text
    end
    
    if not error_message or error_message == "" then
      ui.input_dialog("Enter error message to analyze", function(input)
        if input then
          M._analyze_error(input)
        end
      end, { title = "Claude Code - Debug Error" })
      return
    end
  end
  
  M._analyze_error(error_message)
end

-- Review code
function M.review_code(opts)
  local context = ui.get_current_context()
  local code_to_review = context.selection or context.file_content
  
  if not code_to_review or code_to_review:trim() == "" then
    ui.show_error("No code selected or file is empty")
    return
  end
  
  local loading_win = ui.show_loading("Claude Code", "Reviewing code...")
  
  api.review_code(code_to_review, context, function(response, error)
    if error then
      ui.show_error(error, { loading_win = loading_win })
    else
      ui.show_response(response, {
        title = "Claude Code - Code Review",
        loading_win = loading_win,
      })
    end
  end)
end

-- Review entire file
function M.review_file()
  local context = ui.get_current_context()
  
  if not context.file_content or context.file_content:trim() == "" then
    ui.show_error("Current file is empty")
    return
  end
  
  -- Check file size
  local line_count = select(2, context.file_content:gsub('\n', '\n')) + 1
  if line_count > config.get().features.code_review.max_file_size then
    ui.show_error("File too large for review (max " .. config.get().features.code_review.max_file_size .. " lines)")
    return
  end
  
  local loading_win = ui.show_loading("Claude Code", "Reviewing file: " .. vim.fn.fnamemodify(context.filename, ":t"))
  
  api.review_code(context.file_content, context, function(response, error)
    if error then
      ui.show_error(error, { loading_win = loading_win })
    else
      ui.show_response(response, {
        title = "Claude Code - File Review: " .. vim.fn.fnamemodify(context.filename, ":t"),
        loading_win = loading_win,
      })
    end
  end)
end

-- Generate tests
function M.generate_tests(opts)
  local context = ui.get_current_context()
  local code_to_test = context.selection
  
  if not code_to_test or code_to_test:trim() == "" then
    ui.show_error("Please select code to generate tests for")
    return
  end
  
  local loading_win = ui.show_loading("Claude Code", "Generating tests...")
  
  api.generate_tests(code_to_test, context, function(response, error)
    if error then
      ui.show_error(error, { loading_win = loading_win })
    else
      ui.show_response(response, {
        title = "Claude Code - Generated Tests",
        loading_win = loading_win,
        apply_code = true,
        language = context.language,
      })
    end
  end)
end

-- Open chat interface
function M.open_chat()
  ui.input_dialog("Ask Claude Code anything", function(input)
    if input and input:trim() ~= "" then
      local context = ui.get_current_context()
      local loading_win = ui.show_loading("Claude Code", "Processing query...")
      
      api.request(input, context, function(response, error)
        if error then
          ui.show_error(error, { loading_win = loading_win })
        else
          ui.show_response(response, {
            title = "Claude Code - Chat",
            loading_win = loading_win,
          })
        end
      end)
    end
  end, { title = "Claude Code Chat" })
end

-- Show help
function M.show_help()
  local help_content = [[
# Claude Code for Neovim

## Available Commands

### Code Writing
- :ClaudeWriteFunction - Generate function from description
- :ClaudeImplementTodo - Implement TODO comment  
- :ClaudeExplainCode - Explain selected code

### Debugging
- :ClaudeDebugError - Debug error message
- :ClaudeAnalyzeStack - Analyze stack trace
- :ClaudeSuggestFix - Suggest fix for code issue

### Code Review
- :ClaudeReviewCode - Review selected code
- :ClaudeReviewFile - Review entire file
- :ClaudeSecurityCheck - Security vulnerability check

### Testing
- :ClaudeGenerateTests - Generate tests for code
- :ClaudeGenerateMocks - Generate mock objects
- :ClaudeTestCoverage - Test coverage analysis

### Refactoring
- :ClaudeRefactorExtract - Extract method/class
- :ClaudeRefactorOptimize - Optimize code
- :ClaudeRefactorRename - Intelligent rename

### General
- :ClaudeChat - Open chat interface
- :ClaudeHelp - Show this help
- :ClaudeStatus - Show plugin status

## Default Keybindings
Leader key combinations (configurable):
- <leader>cw - Write function
- <leader>ci - Implement TODO
- <leader>ce - Explain code
- <leader>cd - Debug error
- <leader>cr - Review code
- <leader>ct - Generate tests
- <leader>cc - Open chat

## Configuration
Set ANTHROPIC_API_KEY environment variable or configure in setup:

```lua
require("claude-code").setup({
  api = {
    key = "your-api-key-here"
  }
})
```
]]
  
  ui.show_response(help_content, {
    title = "Claude Code - Help",
    filetype = "markdown",
  })
end

-- Enhanced status display with module information
function M.show_status()
  local cfg = config.get()
  local auth_status = api.check_auth_status()
  
  local status_info = {
    "Claude Code Plugin Status (v" .. M.version .. ")",
    "=" .. string.rep("=", 30 + #M.version),
    "",
    "Initialization:",
    "- Status: " .. (M.initialized and "✅ Initialized" or "❌ Not Initialized"),
    "- Startup Time: " .. (M.startup_time and string.format("%.2fms", M.startup_time) or "N/A"),
    "",
    "Authentication:",
    "- Method: " .. (auth_status.method == "cli" and "Claude CLI" or "HTTP API"),
    "- Status: " .. auth_status.status,
    "",
    "API Configuration:",
    "- Model: " .. cfg.api.model,
    "- Base URL: " .. cfg.api.base_url,
    "- CLI Mode: " .. (cfg.api.use_cli == nil and "Auto-detect" or (cfg.api.use_cli and "Forced" or "Disabled")),
    "",
    "Loaded Modules:",
  }
  
  -- Add module status
  for module_name, loaded in pairs(M.modules_loaded) do
    table.insert(status_info, "- " .. module_name:gsub("^%l", string.upper) .. ": " .. (loaded and "✅ Loaded" or "❌ Not Loaded"))
  end
  
  table.insert(status_info, "")
  table.insert(status_info, "Core Features:")
  table.insert(status_info, "- Code Completion: " .. (cfg.features.completion.enabled and "✅ Enabled" or "❌ Disabled"))
  table.insert(status_info, "- Code Writing: " .. (cfg.features.code_writing.enabled and "✅ Enabled" or "❌ Disabled"))
  table.insert(status_info, "- Debugging: " .. (cfg.features.debugging.enabled and "✅ Enabled" or "❌ Disabled"))
  table.insert(status_info, "- Code Review: " .. (cfg.features.code_review.enabled and "✅ Enabled" or "❌ Disabled"))
  table.insert(status_info, "- Testing: " .. (cfg.features.testing.enabled and "✅ Enabled" or "❌ Disabled"))
  table.insert(status_info, "- Refactoring: " .. (cfg.features.refactoring.enabled and "✅ Enabled" or "❌ Disabled"))
  
  table.insert(status_info, "")
  table.insert(status_info, "Enhanced Features:")
  table.insert(status_info, "- Terminal Integration: " .. (M.modules_loaded.terminal and "✅ Active" or "❌ Inactive"))
  table.insert(status_info, "- Chat Panel: " .. (M.modules_loaded.chat_panel and "✅ Active" or "❌ Inactive"))
  table.insert(status_info, "- File Watching: " .. (M.modules_loaded.file_watcher and "✅ Active" or "❌ Inactive"))
  table.insert(status_info, "- Git Integration: " .. (M.modules_loaded.git and "✅ Active" or "❌ Inactive"))
  table.insert(status_info, "- Which-key Integration: " .. (M.modules_loaded.which_key and "✅ Active" or "❌ Inactive"))
  
  table.insert(status_info, "")
  table.insert(status_info, "Runtime Information:")
  table.insert(status_info, "- Active Requests: " .. api.get_active_requests())
  
  -- Add module-specific information
  if M.modules_loaded.terminal and terminal.is_active() then
    table.insert(status_info, "- Terminal: Active")
  end
  
  if M.modules_loaded.chat_panel then
    local panel_open = chat_panel.is_open() and "Open" or "Closed"
    local history_count = #chat_panel.get_history()
    table.insert(status_info, "- Chat Panel: " .. panel_open .. " (" .. history_count .. " messages)")
  end
  
  if M.modules_loaded.file_watcher then
    local watched_files = file_watcher.get_watched_files()
    table.insert(status_info, "- Watched Files: " .. #watched_files)
  end
  
  if M.modules_loaded.git and git.get_current_project() then
    table.insert(status_info, "- Git Project: " .. vim.fn.fnamemodify(git.get_current_project(), ":t"))
  end
  
  ui.show_response(status_info, {
    title = "Claude Code - Enhanced Status",
  })
end

-- Get plugin information
function M.get_info()
  return {
    version = M.version,
    initialized = M.initialized,
    startup_time = M.startup_time,
    modules_loaded = vim.deepcopy(M.modules_loaded),
  }
end

-- Module management functions
function M.reload_module(module_name)
  if not M.modules_loaded[module_name] then
    vim.notify("Module '" .. module_name .. "' is not loaded", vim.log.levels.WARN)
    return false
  end
  
  -- Module-specific reload logic
  if module_name == "which_key" and M.modules_loaded.which_key then
    which_key.force_reregister()
    vim.notify("Which-key module reloaded", vim.log.levels.INFO)
  elseif module_name == "terminal" and M.modules_loaded.terminal then
    -- Terminal module doesn't need reloading typically
    vim.notify("Terminal module is running", vim.log.levels.INFO)
  else
    vim.notify("Module '" .. module_name .. "' reload not supported", vim.log.levels.WARN)
    return false
  end
  
  return true
end

-- Check if a specific module is loaded and functioning
function M.is_module_active(module_name)
  return M.modules_loaded[module_name] or false
end

-- Toggle completion
function M.toggle_completion()
  local cfg = config.get()
  local new_state = not cfg.features.completion.enabled
  
  config.update({
    features = {
      completion = {
        enabled = new_state
      }
    }
  })
  
  local status = new_state and "enabled" or "disabled"
  ui.show_success("Claude Code completion " .. status)
end

-- Helper functions

function M._generate_code(description, type, context)
  context = context or ui.get_current_context()
  
  local loading_win = ui.show_loading("Claude Code", "Generating " .. (type or "code") .. "...")
  
  api.generate_code(description, context, function(response, error)
    if error then
      ui.show_error(error, { loading_win = loading_win })
    else
      local title = "Claude Code - Generated " .. (type or "Code"):gsub("^%l", string.upper)
      ui.show_response(response, {
        title = title,
        loading_win = loading_win,
        apply_code = true,
        language = context.language,
      })
    end
  end)
end

function M._analyze_error(error_message)
  local context = ui.get_current_context()
  local loading_win = ui.show_loading("Claude Code", "Analyzing error...")
  
  api.analyze_error(error_message, context, function(response, error)
    if error then
      ui.show_error(error, { loading_win = loading_win })
    else
      ui.show_response(response, {
        title = "Claude Code - Error Analysis",
        loading_win = loading_win,
      })
    end
  end)
end

-- Advanced feature implementations

-- Analyze stack trace
function M.analyze_stack_trace()
  -- Try to get stack trace from clipboard or quickfix list
  local stack_trace = vim.fn.getreg("+")
  
  if not stack_trace or stack_trace:trim() == "" then
    -- Try quickfix list
    local qflist = vim.fn.getqflist()
    if #qflist > 0 then
      local traces = {}
      for _, item in ipairs(qflist) do
        if item.text and item.text ~= "" then
          table.insert(traces, item.text)
        end
      end
      stack_trace = table.concat(traces, "\n")
    end
  end
  
  if not stack_trace or stack_trace:trim() == "" then
    ui.input_dialog("Paste stack trace to analyze", function(input)
      if input and input:trim() ~= "" then
        M._analyze_stack_trace(input)
      end
    end, { title = "Claude Code - Stack Trace Analysis" })
    return
  end
  
  M._analyze_stack_trace(stack_trace)
end

function M._analyze_stack_trace(stack_trace)
  local context = ui.get_current_context()
  local loading_win = ui.show_loading("Claude Code", "Analyzing stack trace...")
  
  local prompt = "Analyze this stack trace and provide:\n" ..
                 "1. Root cause analysis\n" ..
                 "2. Specific line numbers and files involved\n" ..
                 "3. Step-by-step debugging approach\n" ..
                 "4. Concrete fix suggestions with code examples\n\n" ..
                 "Stack trace:\n" .. stack_trace
  
  api.request(prompt, context, function(response, error)
    if error then
      ui.show_error(error, { loading_win = loading_win })
    else
      ui.show_response(response, {
        title = "Claude Code - Stack Trace Analysis",
        loading_win = loading_win,
      })
    end
  end)
end

-- Suggest fix for code issue
function M.suggest_fix(opts)
  local context = ui.get_current_context()
  local code_to_fix = context.selection or context.file_content
  
  if not code_to_fix or code_to_fix:trim() == "" then
    ui.show_error("No code selected or file is empty")
    return
  end
  
  local loading_win = ui.show_loading("Claude Code", "Analyzing code for fixes...")
  
  local prompt = "Analyze this code and suggest specific fixes for:\n" ..
                 "1. Potential bugs and logical errors\n" ..
                 "2. Performance issues\n" ..
                 "3. Code quality improvements\n" ..
                 "4. Best practices violations\n" ..
                 "5. Security vulnerabilities\n\n" ..
                 "Provide concrete code examples for each suggestion."
  
  api.request(prompt, context, function(response, error)
    if error then
      ui.show_error(error, { loading_win = loading_win })
    else
      ui.show_response(response, {
        title = "Claude Code - Fix Suggestions",
        loading_win = loading_win,
        apply_code = true,
        language = context.language,
      })
    end
  end)
end

-- Security vulnerability check
function M.security_check(opts)
  local context = ui.get_current_context()
  local code_to_check = context.selection or context.file_content
  
  if not code_to_check or code_to_check:trim() == "" then
    ui.show_error("No code selected or file is empty")
    return
  end
  
  local loading_win = ui.show_loading("Claude Code", "Scanning for security vulnerabilities...")
  
  local prompt = "Perform a comprehensive security audit of this code. Check for:\n" ..
                 "1. SQL injection vulnerabilities\n" ..
                 "2. Cross-site scripting (XSS) risks\n" ..
                 "3. Authentication and authorization flaws\n" ..
                 "4. Input validation issues\n" ..
                 "5. Cryptographic weaknesses\n" ..
                 "6. Information disclosure risks\n" ..
                 "7. OWASP Top 10 vulnerabilities\n\n" ..
                 "For each issue found, provide:\n" ..
                 "- Severity level (Critical/High/Medium/Low)\n" ..
                 "- Detailed explanation\n" ..
                 "- Secure code example fix"
  
  api.request(prompt, context, function(response, error)
    if error then
      ui.show_error(error, { loading_win = loading_win })
    else
      ui.show_response(response, {
        title = "Claude Code - Security Analysis",
        loading_win = loading_win,
      })
    end
  end)
end

-- Generate mock objects
function M.generate_mocks(opts)
  local context = ui.get_current_context()
  local code_to_mock = context.selection
  
  if not code_to_mock or code_to_mock:trim() == "" then
    ui.show_error("Please select code (class, interface, or function) to generate mocks for")
    return
  end
  
  local loading_win = ui.show_loading("Claude Code", "Generating mock objects...")
  
  local prompt = "Generate comprehensive mock objects for the selected code. Include:\n" ..
                 "1. Mock implementations for all methods/functions\n" ..
                 "2. Configurable return values and behaviors\n" ..
                 "3. Spy/stub functionality where appropriate\n" ..
                 "4. Setup and teardown helpers\n" ..
                 "5. Example usage in tests\n\n" ..
                 "Use the appropriate mocking framework for the language (e.g., unittest.mock for Python, Jest for JavaScript, etc.)"
  
  api.request(prompt, context, function(response, error)
    if error then
      ui.show_error(error, { loading_win = loading_win })
    else
      ui.show_response(response, {
        title = "Claude Code - Generated Mocks",
        loading_win = loading_win,
        apply_code = true,
        language = context.language,
      })
    end
  end)
end

-- Test coverage analysis
function M.test_coverage_analysis()
  local context = ui.get_current_context()
  local loading_win = ui.show_loading("Claude Code", "Analyzing test coverage...")
  
  local prompt = "Analyze the current file for test coverage and suggest:\n" ..
                 "1. Areas of code that need more test coverage\n" ..
                 "2. Missing edge cases and boundary conditions\n" ..
                 "3. Integration test opportunities\n" ..
                 "4. Performance test scenarios\n" ..
                 "5. Specific test cases to add with examples\n\n" ..
                 "If this is a test file, analyze what's missing from the test suite."
  
  api.request(prompt, context, function(response, error)
    if error then
      ui.show_error(error, { loading_win = loading_win })
    else
      ui.show_response(response, {
        title = "Claude Code - Test Coverage Analysis",
        loading_win = loading_win,
      })
    end
  end)
end

-- Extract method/class refactoring
function M.refactor_extract(opts)
  local context = ui.get_current_context()
  local code_to_extract = context.selection
  
  if not code_to_extract or code_to_extract:trim() == "" then
    ui.show_error("Please select code to extract into a method or class")
    return
  end
  
  ui.select_dialog(
    {"Extract Method", "Extract Class", "Extract Variable", "Extract Interface"},
    function(choice)
      if choice then
        M._perform_extraction(choice, code_to_extract, context)
      end
    end,
    {
      title = "Claude Code - Extract Refactoring",
      prompt = "What would you like to extract?",
    }
  )
end

function M._perform_extraction(extract_type, code, context)
  local loading_win = ui.show_loading("Claude Code", "Performing " .. extract_type:lower() .. " refactoring...")
  
  local prompt = "Perform a " .. extract_type:lower() .. " refactoring on the selected code:\n\n" ..
                 "1. Create appropriate extracted construct with a meaningful name\n" ..
                 "2. Update the original code to use the extracted construct\n" ..
                 "3. Ensure all dependencies and imports are handled\n" ..
                 "4. Maintain the same functionality and behavior\n" ..
                 "5. Follow language-specific conventions and best practices\n\n" ..
                 "Show both the extracted code and the updated original code."
  
  api.request(prompt, context, function(response, error)
    if error then
      ui.show_error(error, { loading_win = loading_win })
    else
      ui.show_response(response, {
        title = "Claude Code - " .. extract_type .. " Refactoring",
        loading_win = loading_win,
        apply_code = true,
        language = context.language,
      })
    end
  end)
end

-- Optimize code performance
function M.refactor_optimize(opts)
  local context = ui.get_current_context()
  local code_to_optimize = context.selection or context.file_content
  
  if not code_to_optimize or code_to_optimize:trim() == "" then
    ui.show_error("No code selected or file is empty")
    return
  end
  
  local loading_win = ui.show_loading("Claude Code", "Analyzing code for optimizations...")
  
  local prompt = "Analyze and optimize this code for:\n" ..
                 "1. Performance improvements (time complexity, memory usage)\n" ..
                 "2. Algorithm optimizations\n" ..
                 "3. Data structure improvements\n" ..
                 "4. Resource utilization\n" ..
                 "5. Caching opportunities\n" ..
                 "6. Database query optimization (if applicable)\n" ..
                 "7. Parallelization opportunities\n\n" ..
                 "Provide the optimized code with comments explaining the improvements and their benefits."
  
  api.request(prompt, context, function(response, error)
    if error then
      ui.show_error(error, { loading_win = loading_win })
    else
      ui.show_response(response, {
        title = "Claude Code - Performance Optimization",
        loading_win = loading_win,
        apply_code = true,
        language = context.language,
      })
    end
  end)
end

-- Intelligent rename suggestions
function M.refactor_rename()
  local context = ui.get_current_context()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local current_word = vim.fn.expand("<cword>")
  
  if not current_word or current_word == "" then
    ui.show_error("Place cursor on a variable, function, or class name to rename")
    return
  end
  
  local loading_win = ui.show_loading("Claude Code", "Analyzing naming opportunities...")
  
  local prompt = "Analyze the identifier '" .. current_word .. "' in this code context and suggest:\n" ..
                 "1. More descriptive and meaningful names\n" ..
                 "2. Names that follow language-specific conventions\n" ..
                 "3. Names that better reflect the purpose/functionality\n" ..
                 "4. Consider scope and usage patterns\n" ..
                 "5. Avoid naming conflicts\n\n" ..
                 "Provide 3-5 alternative names with explanations for why each would be better."
  
  api.request(prompt, context, function(response, error)
    if error then
      ui.show_error(error, { loading_win = loading_win })
    else
      ui.show_response(response, {
        title = "Claude Code - Rename Suggestions for '" .. current_word .. "'",
        loading_win = loading_win,
      })
    end
  end)
end

return M