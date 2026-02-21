-- Health check for Claude Code Neovim Plugin
local M = {}

-- Check if Neovim version is compatible
local function check_neovim_version()
  local min_version = {0, 8, 0}
  local current = vim.version()
  
  if vim.version.cmp(current, min_version) >= 0 then
    vim.health.ok(string.format("Neovim version: %d.%d.%d (>= 0.8.0)", current.major, current.minor, current.patch))
  else
    vim.health.error(
      string.format("Neovim version: %d.%d.%d", current.major, current.minor, current.patch),
      "Please upgrade to Neovim 0.8.0 or later"
    )
  end
end

-- Check for required external tools
local function check_external_tools()
  -- Check for curl
  local curl_check = vim.fn.executable("curl")
  if curl_check == 1 then
    vim.health.ok("curl is available")
  else
    vim.health.error("curl is not available", "Please install curl for API requests")
  end
  
  -- Check for git (optional but recommended)
  local git_check = vim.fn.executable("git")
  if git_check == 1 then
    vim.health.ok("git is available")
  else
    vim.health.warn("git is not available", "Git is recommended for better context understanding")
  end
end

-- Check API configuration
local function check_api_configuration()
  local config = require("claude-code.config")
  local cfg = config.get()
  
  -- Check API key
  if cfg.api.key then
    if cfg.api.key:match("^sk%-") then
      vim.health.ok("API key is configured and appears valid")
    else
      vim.health.warn("API key is configured but format seems unusual", "Anthropic keys usually start with 'sk-'")
    end
  else
    vim.health.warn("API key is not configured", {
      "Set ANTHROPIC_API_KEY environment variable",
      "Or configure it in setup: api = { key = 'your-key' }"
    })
  end
  
  -- Check model
  local supported_models = {
    "claude-3-5-sonnet-20241022",
    "claude-3-opus-20240229",
    "claude-3-sonnet-20240229",
    "claude-3-haiku-20240307"
  }
  
  local model_supported = false
  for _, model in ipairs(supported_models) do
    if cfg.api.model == model then
      model_supported = true
      break
    end
  end
  
  if model_supported then
    vim.health.ok("Model '" .. cfg.api.model .. "' is supported")
  else
    vim.health.warn("Model '" .. cfg.api.model .. "' may not be supported", "Consider using a supported model")
  end
  
  -- Check Claude CLI availability
  local cli_available = vim.fn.executable("claude")
  if cli_available == 1 then
    vim.health.ok("Claude CLI is available")
    
    -- Test CLI authentication
    local handle = io.popen("claude --version 2>&1")
    local result = handle:read("*a")
    handle:close()
    
    if result and result:match("claude") then
      vim.health.ok("Claude CLI appears to be working")
    else
      vim.health.warn("Claude CLI may not be properly configured")
    end
  else
    if not cfg.api.key then
      vim.health.error("Neither API key nor Claude CLI is available", {
        "Install Claude CLI: https://claude.ai/cli",
        "Or set ANTHROPIC_API_KEY environment variable"
      })
    else
      vim.health.info("Claude CLI not available (using API key instead)")
    end
  end
end

-- Check plugin features
local function check_plugin_features()
  local config = require("claude-code.config")
  local cfg = config.get()
  
  local enabled_features = {}
  local disabled_features = {}
  
  for feature_name, feature_config in pairs(cfg.features) do
    if feature_config.enabled then
      table.insert(enabled_features, feature_name)
    else
      table.insert(disabled_features, feature_name)
    end
  end
  
  if #enabled_features > 0 then
    vim.health.ok("Enabled features: " .. table.concat(enabled_features, ", "))
  end
  
  if #disabled_features > 0 then
    vim.health.info("Disabled features: " .. table.concat(disabled_features, ", "))
  end
end

-- Check for common issues
local function check_common_issues()
  -- Check if plugin is loaded
  local ok, _ = pcall(require, "claude-code")
  if ok then
    vim.health.ok("Plugin loaded successfully")
  else
    vim.health.error("Plugin failed to load", "Check your plugin manager configuration")
  end
  
  -- Check if commands are registered
  local commands = {
    "ClaudeWriteFunction",
    "ClaudeExplainCode", 
    "ClaudeDebugError",
    "ClaudeReviewCode",
    "ClaudeGenerateTests",
    "ClaudeChat",
    "ClaudeStatus",
    "ClaudeHelp"
  }
  
  local registered_commands = {}
  local missing_commands = {}
  
  for _, cmd in ipairs(commands) do
    if vim.fn.exists(":" .. cmd) == 2 then
      table.insert(registered_commands, cmd)
    else
      table.insert(missing_commands, cmd)
    end
  end
  
  if #registered_commands > 0 then
    vim.health.ok(#registered_commands .. " commands registered successfully")
  end
  
  if #missing_commands > 0 then
    vim.health.error(
      "Missing commands: " .. table.concat(missing_commands, ", "),
      "Plugin may not be properly initialized"
    )
  end
end

-- Check network connectivity
local function check_network_connectivity()
  local handle = io.popen("curl -s --max-time 5 -o /dev/null -w '%{http_code}' https://api.anthropic.com")
  if handle then
    local response = handle:read("*a")
    handle:close()
    
    if response and response ~= "" then
      local status_code = tonumber(response)
      if status_code and status_code >= 200 and status_code < 500 then
        vim.health.ok("Network connectivity to Anthropic API is working")
      else
        vim.health.warn("Network connectivity issues detected", "HTTP status: " .. (response or "unknown"))
      end
    else
      vim.health.warn("Could not test network connectivity")
    end
  else
    vim.health.warn("Could not test network connectivity", "curl command failed")
  end
end

-- Main health check function
function M.check()
  vim.health.start("Claude Code Neovim Plugin")
  
  check_neovim_version()
  check_external_tools()
  check_api_configuration()
  check_plugin_features()
  check_common_issues()
  check_network_connectivity()
  
  vim.health.start("Troubleshooting")
  vim.health.info("Run :ClaudeStatus for detailed plugin information")
  vim.health.info("Check :ClaudeHelp for usage instructions")
  vim.health.info("Visit https://github.com/username/claude-code.nvim for documentation")
end

return M