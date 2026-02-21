-- Configuration module for Claude Code Neovim Plugin
local M = {}

-- Default configuration for Claude Code
M.defaults = {
  -- Claude Code API configuration
  api = {
    key = nil, -- Will be read from environment variable ANTHROPIC_API_KEY
    base_url = "https://api.anthropic.com/v1",
    model = "claude-3-5-sonnet-20241022", -- Latest Claude 3.5 Sonnet optimized for code
    max_tokens = 4096,
    temperature = 0.1, -- Lower temperature for more deterministic code generation
    timeout = 30000, -- 30 seconds timeout
    use_cli = nil, -- Auto-detect: nil = auto, true = force CLI, false = force API
  },

  -- Claude Code specific features configuration
  features = {
    completion = {
      enabled = true,
      trigger_length = 2, -- Minimum characters before triggering completion
      max_context_lines = 100, -- Context lines to send to Claude Code
      debounce_ms = 500, -- Debounce completion requests
      include_imports = true, -- Include import statements in context
      include_comments = true, -- Include comments in context for better understanding
    },
    
    code_writing = {
      enabled = true,
      include_type_hints = true, -- Generate type hints when applicable
      include_docstrings = true, -- Generate documentation strings
      include_error_handling = true, -- Include proper error handling in generated code
      follow_conventions = true, -- Follow language-specific conventions
    },
    
    debugging = {
      enabled = true,
      explain_errors = true, -- Provide detailed error explanations
      suggest_fixes = true, -- Suggest specific fixes
      analyze_stack_trace = true, -- Analyze complete stack traces
      include_related_code = true, -- Include related code context
    },
    
    code_review = {
      enabled = true,
      check_security = true, -- Check for security vulnerabilities
      check_performance = true, -- Analyze performance issues
      check_maintainability = true, -- Check code maintainability
      suggest_patterns = true, -- Suggest better design patterns
      max_file_size = 10000, -- Maximum file size for review (in lines)
    },
    
    testing = {
      enabled = true,
      generate_edge_cases = true, -- Generate edge case tests
      include_mocks = true, -- Generate mock objects when needed
      test_coverage_suggestions = true, -- Suggest additional test cases
      integration_tests = true, -- Support integration test generation
    },
    
    refactoring = {
      enabled = true,
      extract_methods = true, -- Extract method suggestions
      optimize_algorithms = true, -- Algorithm optimization suggestions
      improve_naming = true, -- Improve variable/function naming
      suggest_architecture = true, -- Architectural improvement suggestions
    },
  },

  -- UI configuration
  ui = {
    float_border = "rounded", -- Border style for floating windows
    float_width = 0.8, -- Width of floating windows (as fraction of screen)
    float_height = 0.6, -- Height of floating windows (as fraction of screen)
    progress_indicator = true, -- Show progress indicators
    syntax_highlighting = true, -- Enable syntax highlighting in responses
    auto_close_delay = 5000, -- Auto-close success messages after 5 seconds
  },

  -- Keybindings configuration
  keymaps = {
    completion = {
      accept = "<Tab>", -- Accept completion
      next = "<C-n>", -- Next completion
      prev = "<C-p>", -- Previous completion
      dismiss = "<Esc>", -- Dismiss completion
    },
    
    commands = {
      -- Code writing commands
      write_function = "<leader>cw", -- Write function from description
      implement_todo = "<leader>ci", -- Implement TODO comment
      explain_code = "<leader>ce", -- Explain selected code
      
      -- Debugging commands
      debug_error = "<leader>cd", -- Debug error at cursor
      analyze_stack = "<leader>cs", -- Analyze stack trace
      suggest_fix = "<leader>cf", -- Suggest fix for issue
      
      -- Code review commands
      review_code = "<leader>cr", -- Review selected code
      review_file = "<leader>cR", -- Review entire file
      security_check = "<leader>cS", -- Security vulnerability check
      
      -- Testing commands
      generate_tests = "<leader>ct", -- Generate tests for function
      generate_mocks = "<leader>cm", -- Generate mock objects
      test_coverage = "<leader>cC", -- Test coverage analysis
      
      -- Refactoring commands
      refactor_extract = "<leader>re", -- Extract method/class
      refactor_optimize = "<leader>ro", -- Optimize code
      refactor_rename = "<leader>rn", -- Intelligent rename suggestions
      
      -- General commands
      claude_chat = "<leader>cc", -- Open Claude Code chat
      claude_help = "<leader>ch", -- Show Claude Code help
    },
  },

  -- Logging configuration
  logging = {
    enabled = false, -- Enable logging for debugging
    level = "info", -- Log level: debug, info, warn, error
    file = vim.fn.stdpath("cache") .. "/claude-code.log", -- Log file path
  },

  -- Claude Code specific prompts
  prompts = {
    code_completion = "Complete this code considering the context and best practices:",
    code_generation = "Generate clean, well-documented code with proper error handling:",
    code_explanation = "Explain this code in detail, including its purpose and how it works:",
    debug_analysis = "Analyze this error and provide specific, actionable solutions:",
    code_review = "Review this code for quality, security, performance, and maintainability:",
    test_generation = "Generate comprehensive tests including edge cases and proper assertions:",
    refactoring = "Suggest refactoring improvements focusing on clean code principles:",
  },
}

-- Current configuration (starts with defaults)
M.config = vim.deepcopy(M.defaults)

-- Setup function to configure the plugin
function M.setup(user_config)
  if user_config then
    M.config = vim.tbl_deep_extend("force", M.config, user_config)
  end
  
  -- Set API key from environment if not provided
  if not M.config.api.key then
    M.config.api.key = vim.env.ANTHROPIC_API_KEY or vim.env.CLAUDE_API_KEY
  end
  
  -- Validate configuration
  M.validate()
  
  -- Setup keymaps
  M.setup_keymaps()
end

-- Validate configuration
function M.validate()
  -- Check if we should use CLI or HTTP API
  local use_cli = M.config.api.use_cli
  if use_cli == nil then
    -- Auto-detect: use CLI if available and no API key, otherwise use API key if available
    local handle = io.popen("claude --version 2>/dev/null")
    local result = handle:read("*a")
    handle:close()
    local cli_available = result and result ~= ""
    use_cli = cli_available and not M.config.api.key
  end
  
  -- Only warn about API key if not using CLI
  if not use_cli and not M.config.api.key then
    vim.notify("Claude Code: API key not found. Set ANTHROPIC_API_KEY environment variable or configure it manually.", vim.log.levels.WARN)
  end
  
  if M.config.api.max_tokens > 8192 then
    vim.notify("Claude Code: max_tokens reduced to 8192 (Claude's limit)", vim.log.levels.WARN)
    M.config.api.max_tokens = 8192
  end
  
  if M.config.api.temperature > 1.0 then
    M.config.api.temperature = 1.0
  elseif M.config.api.temperature < 0.0 then
    M.config.api.temperature = 0.0
  end
end

-- Setup keymaps
function M.setup_keymaps()
  local function map(mode, lhs, rhs, opts)
    opts = opts or {}
    opts.noremap = opts.noremap == nil and true or opts.noremap
    opts.silent = opts.silent == nil and true or opts.silent
    vim.keymap.set(mode, lhs, rhs, opts)
  end

  local keymaps = M.config.keymaps.commands
  
  -- Code writing commands
  map("n", keymaps.write_function, ":ClaudeWriteFunction<CR>", { desc = "Claude: Write function" })
  map("n", keymaps.implement_todo, ":ClaudeImplementTodo<CR>", { desc = "Claude: Implement TODO" })
  map("n", keymaps.explain_code, ":ClaudeExplainCode<CR>", { desc = "Claude: Explain code" })
  map("v", keymaps.explain_code, ":ClaudeExplainCode<CR>", { desc = "Claude: Explain selected code" })
  
  -- Debugging commands
  map("n", keymaps.debug_error, ":ClaudeDebugError<CR>", { desc = "Claude: Debug error" })
  map("n", keymaps.analyze_stack, ":ClaudeAnalyzeStack<CR>", { desc = "Claude: Analyze stack trace" })
  map("n", keymaps.suggest_fix, ":ClaudeSuggestFix<CR>", { desc = "Claude: Suggest fix" })
  
  -- Code review commands
  map("n", keymaps.review_code, ":ClaudeReviewCode<CR>", { desc = "Claude: Review code" })
  map("v", keymaps.review_code, ":ClaudeReviewCode<CR>", { desc = "Claude: Review selected code" })
  map("n", keymaps.review_file, ":ClaudeReviewFile<CR>", { desc = "Claude: Review file" })
  map("n", keymaps.security_check, ":ClaudeSecurityCheck<CR>", { desc = "Claude: Security check" })
  
  -- Testing commands
  map("n", keymaps.generate_tests, ":ClaudeGenerateTests<CR>", { desc = "Claude: Generate tests" })
  map("n", keymaps.generate_mocks, ":ClaudeGenerateMocks<CR>", { desc = "Claude: Generate mocks" })
  map("n", keymaps.test_coverage, ":ClaudeTestCoverage<CR>", { desc = "Claude: Test coverage" })
  
  -- Refactoring commands
  map("n", keymaps.refactor_extract, ":ClaudeRefactorExtract<CR>", { desc = "Claude: Extract method/class" })
  map("v", keymaps.refactor_extract, ":ClaudeRefactorExtract<CR>", { desc = "Claude: Extract selected code" })
  map("n", keymaps.refactor_optimize, ":ClaudeRefactorOptimize<CR>", { desc = "Claude: Optimize code" })
  map("n", keymaps.refactor_rename, ":ClaudeRefactorRename<CR>", { desc = "Claude: Intelligent rename" })
  
  -- General commands
  map("n", keymaps.claude_chat, ":ClaudeChat<CR>", { desc = "Claude: Open chat" })
  map("n", keymaps.claude_help, ":ClaudeHelp<CR>", { desc = "Claude: Show help" })
end

-- Get current configuration
function M.get()
  return M.config
end

-- Update configuration at runtime
function M.update(updates)
  M.config = vim.tbl_deep_extend("force", M.config, updates)
  M.validate()
end

return M