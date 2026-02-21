-- Configuration module for Claude Code Neovim Plugin
local M = {}

-- Configuration schema version for migration support
M.SCHEMA_VERSION = "1.0.0"

-- Configuration validation schemas
local validation_schemas = {
  api = {
    key = { type = "string", optional = true },
    base_url = { type = "string", pattern = "^https?://" },
    model = { type = "string", enum = {
      "claude-3-5-sonnet-20241022",
      "claude-3-5-haiku-20241022", 
      "claude-3-opus-20240229"
    }},
    max_tokens = { type = "number", min = 1, max = 8192 },
    temperature = { type = "number", min = 0.0, max = 1.0 },
    timeout = { type = "number", min = 1000, max = 300000 },
    use_cli = { type = "boolean", optional = true },
  },
  terminal = {
    enabled = { type = "boolean" },
    toggle_key = { type = "string" },
    auto_cd_git_root = { type = "boolean" },
    session_persistence = { type = "boolean" },
    window_config = {
      position = { type = "string", enum = { "float", "bottom", "right", "top", "left" } },
      float_opts = {
        width = { type = "number", min = 0.1, max = 1.0 },
        height = { type = "number", min = 0.1, max = 1.0 },
      },
    },
  },
  git = {
    enabled = { type = "boolean" },
    auto_cd_root = { type = "boolean" },
    include_git_context = { type = "boolean" },
    cache_duration = { type = "number", min = 5, max = 300 },
  },
  file_watcher = {
    enabled = { type = "boolean" },
    auto_reload = { type = "boolean" },
    reload_delay = { type = "number", min = 50, max = 5000 },
    max_file_size = { type = "number", min = 1024, max = 100 * 1024 * 1024 },
  },
  which_key = {
    enabled = { type = "boolean" },
    auto_register = { type = "boolean" },
    prefix = { type = "string" },
    show_icons = { type = "boolean" },
    timeout = { type = "number", min = 100, max = 2000 },
  },
}

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

-- Validate a single field against its schema
local function validate_field(field_name, value, schema)
  local errors = {}
  
  -- Check if field is required
  if value == nil then
    if not schema.optional then
      table.insert(errors, field_name .. " is required")
    end
    return errors
  end
  
  -- Type validation
  if schema.type then
    local actual_type = type(value)
    if actual_type ~= schema.type then
      table.insert(errors, field_name .. " must be " .. schema.type .. ", got " .. actual_type)
      return errors -- Early return for type mismatch
    end
  end
  
  -- Number range validation
  if schema.type == "number" then
    if schema.min and value < schema.min then
      table.insert(errors, field_name .. " must be >= " .. schema.min .. ", got " .. value)
    end
    if schema.max and value > schema.max then
      table.insert(errors, field_name .. " must be <= " .. schema.max .. ", got " .. value)
    end
  end
  
  -- String pattern validation
  if schema.type == "string" and schema.pattern then
    if not string.match(value, schema.pattern) then
      table.insert(errors, field_name .. " does not match required pattern: " .. schema.pattern)
    end
  end
  
  -- Enum validation
  if schema.enum then
    local valid = false
    for _, enum_value in ipairs(schema.enum) do
      if value == enum_value then
        valid = true
        break
      end
    end
    if not valid then
      table.insert(errors, field_name .. " must be one of: " .. table.concat(schema.enum, ", "))
    end
  end
  
  return errors
end

-- Validate configuration section recursively
local function validate_section(section_name, config_section, schema_section, path)
  path = path or section_name
  local errors = {}
  
  if type(config_section) ~= "table" or type(schema_section) ~= "table" then
    return errors
  end
  
  -- Validate each field in the schema
  for field_name, field_schema in pairs(schema_section) do
    local field_path = path .. "." .. field_name
    local field_value = config_section[field_name]
    
    if type(field_schema) == "table" and not field_schema.type then
      -- Nested object validation
      local nested_errors = validate_section(field_name, field_value or {}, field_schema, field_path)
      vim.list_extend(errors, nested_errors)
    else
      -- Field validation
      local field_errors = validate_field(field_path, field_value, field_schema)
      vim.list_extend(errors, field_errors)
    end
  end
  
  -- Check for unknown fields
  if config_section then
    for field_name, _ in pairs(config_section) do
      if not schema_section[field_name] then
        table.insert(errors, path .. "." .. field_name .. " is not a recognized configuration option")
      end
    end
  end
  
  return errors
end

-- Apply automatic fixes for common configuration issues
local function apply_fixes(config)
  local fixes_applied = {}
  
  -- Fix API configuration
  if config.api then
    -- Clamp max_tokens to Claude's limits
    if config.api.max_tokens and config.api.max_tokens > 8192 then
      config.api.max_tokens = 8192
      table.insert(fixes_applied, "max_tokens clamped to 8192 (Claude's limit)")
    end
    
    -- Clamp temperature to valid range
    if config.api.temperature then
      if config.api.temperature > 1.0 then
        config.api.temperature = 1.0
        table.insert(fixes_applied, "temperature clamped to 1.0")
      elseif config.api.temperature < 0.0 then
        config.api.temperature = 0.0
        table.insert(fixes_applied, "temperature clamped to 0.0")
      end
    end
  end
  
  return fixes_applied
end

-- Migrate configuration from older versions
local function migrate_config(config, from_version)
  local migrations_applied = {}
  
  -- Add version if missing
  if not config._version then
    config._version = M.SCHEMA_VERSION
    table.insert(migrations_applied, "Added schema version")
  end
  
  -- Migration logic would go here for future versions
  -- Example:
  -- if from_version == "0.9.0" then
  --   config.new_field = config.old_field
  --   config.old_field = nil
  --   table.insert(migrations_applied, "Migrated old_field to new_field")
  -- end
  
  return migrations_applied
end

-- Comprehensive validation function
function M.validate()
  local all_errors = {}
  local all_fixes = {}
  local all_migrations = {}
  
  -- Check for schema version and migrate if needed
  local config_version = M.config._version or "0.0.0"
  if config_version ~= M.SCHEMA_VERSION then
    local migrations = migrate_config(M.config, config_version)
    vim.list_extend(all_migrations, migrations)
  end
  
  -- Apply automatic fixes
  local fixes = apply_fixes(M.config)
  vim.list_extend(all_fixes, fixes)
  
  -- Validate each configuration section
  for section_name, section_schema in pairs(validation_schemas) do
    local section_config = M.config[section_name]
    if section_config then
      local section_errors = validate_section(section_name, section_config, section_schema)
      vim.list_extend(all_errors, section_errors)
    end
  end
  
  -- Handle API-specific validation
  local api_warnings = M.validate_api_config()
  
  -- Report results
  M.report_validation_results(all_errors, all_fixes, all_migrations, api_warnings)
  
  return #all_errors == 0
end

-- API-specific validation logic
function M.validate_api_config()
  local warnings = {}
  
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
    table.insert(warnings, "API key not found. Set ANTHROPIC_API_KEY environment variable or configure it manually.")
  end
  
  return warnings
end

-- Report validation results to user
function M.report_validation_results(errors, fixes, migrations, warnings)
  -- Report migrations
  if #migrations > 0 then
    vim.notify("Claude Code: Applied " .. #migrations .. " configuration migrations", vim.log.levels.INFO)
    for _, migration in ipairs(migrations) do
      vim.notify("  • " .. migration, vim.log.levels.INFO)
    end
  end
  
  -- Report fixes
  if #fixes > 0 then
    vim.notify("Claude Code: Applied " .. #fixes .. " automatic fixes", vim.log.levels.INFO)
    for _, fix in ipairs(fixes) do
      vim.notify("  • " .. fix, vim.log.levels.INFO)
    end
  end
  
  -- Report warnings
  if #warnings > 0 then
    for _, warning in ipairs(warnings) do
      vim.notify("Claude Code: " .. warning, vim.log.levels.WARN)
    end
  end
  
  -- Report errors
  if #errors > 0 then
    vim.notify("Claude Code: Found " .. #errors .. " configuration errors:", vim.log.levels.ERROR)
    for _, error in ipairs(errors) do
      vim.notify("  • " .. error, vim.log.levels.ERROR)
    end
    vim.notify("Please fix these errors in your Claude Code configuration", vim.log.levels.ERROR)
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

-- Export configuration for inspection
function M.export_config(include_sensitive)
  include_sensitive = include_sensitive or false
  local exported = vim.deepcopy(M.config)
  
  -- Remove sensitive information unless explicitly requested
  if not include_sensitive and exported.api then
    if exported.api.key then
      exported.api.key = "<redacted>"
    end
  end
  
  return exported
end

-- Get configuration schema for documentation
function M.get_schema()
  return vim.deepcopy(validation_schemas)
end

-- Validate user configuration without applying it
function M.validate_user_config(user_config)
  local temp_config = vim.tbl_deep_extend("force", M.defaults, user_config or {})
  local errors = {}
  
  -- Validate each section
  for section_name, section_schema in pairs(validation_schemas) do
    local section_config = temp_config[section_name]
    if section_config then
      local section_errors = validate_section(section_name, section_config, section_schema)
      vim.list_extend(errors, section_errors)
    end
  end
  
  return #errors == 0, errors
end

-- Generate configuration template
function M.generate_config_template()
  return {
    ["-- Claude Code Configuration Template"] = "",
    ["-- Copy and modify as needed"] = "",
    [""] = "",
    api = {
      key = "vim.env.ANTHROPIC_API_KEY", -- or your API key
      model = "claude-3-5-sonnet-20241022",
      max_tokens = 4096,
      temperature = 0.1,
    },
    terminal = {
      enabled = true,
      toggle_key = "<F12>",
      auto_cd_git_root = true,
      session_persistence = true,
    },
    git = {
      enabled = true,
      auto_cd_root = true,
      include_git_context = true,
      cache_duration = 30,
    },
    file_watcher = {
      enabled = true,
      auto_reload = true,
      reload_delay = 100,
    },
    which_key = {
      enabled = true,
      auto_register = true,
      prefix = "<leader>c",
      show_icons = true,
    },
  }
end

-- Show configuration help
function M.show_config_help()
  local help_lines = {
    "Claude Code Configuration Help",
    "==============================",
    "",
    "Schema Version: " .. M.SCHEMA_VERSION,
    "Current Config Version: " .. (M.config._version or "unknown"),
    "",
    "Available Sections:",
  }
  
  for section_name, _ in pairs(validation_schemas) do
    table.insert(help_lines, "  • " .. section_name)
  end
  
  table.insert(help_lines, "")
  table.insert(help_lines, "Commands:")
  table.insert(help_lines, "  :ClaudeConfigValidate  - Validate current configuration")
  table.insert(help_lines, "  :ClaudeConfigShow      - Show current configuration")
  table.insert(help_lines, "  :ClaudeConfigTemplate  - Generate configuration template")
  table.insert(help_lines, "  :ClaudeConfigSchema    - Show configuration schema")
  
  require("claude-code.ui").show_response(help_lines, {
    title = "Configuration Help",
    filetype = "text",
  })
end

-- Setup configuration management commands
function M.setup_config_commands()
  -- Validate configuration
  vim.api.nvim_create_user_command("ClaudeConfigValidate", function()
    local is_valid = M.validate()
    if is_valid then
      vim.notify("Claude Code configuration is valid ✅", vim.log.levels.INFO)
    end
  end, {
    desc = "Validate Claude Code configuration",
  })
  
  -- Show current configuration
  vim.api.nvim_create_user_command("ClaudeConfigShow", function(opts)
    local include_sensitive = opts.bang
    local exported = M.export_config(include_sensitive)
    local content = vim.inspect(exported, { indent = "  " })
    
    require("claude-code.ui").show_response(content, {
      title = "Current Configuration" .. (include_sensitive and "" or " (sensitive data redacted)"),
      filetype = "lua",
    })
  end, {
    desc = "Show current configuration (add ! to include sensitive data)",
    bang = true,
  })
  
  -- Generate configuration template
  vim.api.nvim_create_user_command("ClaudeConfigTemplate", function()
    local template = M.generate_config_template()
    local content = "require('claude-code').setup(" .. vim.inspect(template, { indent = "  " }) .. ")"
    
    require("claude-code.ui").show_response(content, {
      title = "Configuration Template",
      filetype = "lua",
    })
  end, {
    desc = "Generate Claude Code configuration template",
  })
  
  -- Show configuration schema
  vim.api.nvim_create_user_command("ClaudeConfigSchema", function()
    local schema = M.get_schema()
    local content = vim.inspect(schema, { indent = "  " })
    
    require("claude-code.ui").show_response(content, {
      title = "Configuration Schema",
      filetype = "lua",
    })
  end, {
    desc = "Show configuration schema",
  })
  
  -- Show configuration help
  vim.api.nvim_create_user_command("ClaudeConfigHelp", function()
    M.show_config_help()
  end, {
    desc = "Show configuration help",
  })
end

return M
