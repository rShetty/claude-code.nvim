-- Claude Code API client for Neovim plugin
-- Supports both Claude CLI (authenticated) and HTTP API (with key)
local config = require("claude-code.config")
local M = {}

-- Internal state
local active_requests = {}

-- Check if Claude CLI is available
local function check_claude_cli()
  -- Check if claude command exists
  local handle = io.popen("which claude 2>/dev/null")
  local result = handle:read("*a")
  handle:close()

  if not result or result:gsub("%s+", "") == "" then
    return false
  end

  -- Verify it runs by checking version (lightweight check)
  local ver_handle = io.popen("claude --version 2>/dev/null")
  local ver_result = ver_handle:read("*a")
  ver_handle:close()

  return ver_result ~= nil and ver_result ~= ""
end

-- Claude Code CLI request function (using authenticated CLI)
local function make_claude_cli_request(prompt, callback)
  -- Use -p (print mode) for non-interactive usage
  local cmd = { "claude", "-p" }

  -- Create unique request ID
  local request_id = tostring(os.time()) .. math.random(1000, 9999)

  local stdout_data = {}
  local stderr_data = {}
  local callback_called = false

  -- Ensure callback is only called once
  local function safe_callback(response, err)
    if callback_called then return end
    callback_called = true
    vim.schedule(function()
      callback(response, err)
    end)
  end

  local job_id = vim.fn.jobstart(cmd, {
    stdin = "pipe",
    stdout_buffered = true,
    stderr_buffered = true,
    on_exit = function(_, exit_code)
      active_requests[request_id] = nil

      local response = table.concat(stdout_data, "\n")
      -- Trim trailing whitespace from buffered output
      response = response:gsub("%s+$", "")

      if exit_code == 0 then
        if response ~= "" then
          safe_callback(response, nil)
        else
          safe_callback(nil, "Claude CLI returned empty response")
        end
      else
        local error_msg = table.concat(stderr_data, "\n"):gsub("%s+$", "")
        if error_msg ~= "" then
          safe_callback(nil, "Claude CLI error: " .. error_msg)
        else
          safe_callback(nil, "Claude CLI failed (exit code: " .. exit_code .. "). Make sure you're authenticated with 'claude auth login'")
        end
      end
    end,
    on_stdout = function(_, data)
      if data then
        vim.list_extend(stdout_data, data)
      end
    end,
    on_stderr = function(_, data)
      if data then
        vim.list_extend(stderr_data, data)
      end
    end,
  })
  
  if job_id > 0 then
    -- Send the prompt to Claude CLI via stdin
    vim.fn.chansend(job_id, prompt .. "\n")
    vim.fn.chanclose(job_id, "stdin")
    
    active_requests[request_id] = job_id
    return request_id
  else
    callback(nil, "Failed to start Claude CLI")
    return nil
  end
end

-- HTTP request function (fallback for API key users)
local function make_http_request(url, headers, body, callback)
  local cmd = { "curl", "-s", "-X", "POST" }

  -- Add headers
  for key, value in pairs(headers) do
    table.insert(cmd, "-H")
    table.insert(cmd, key .. ": " .. value)
  end

  -- Add body
  if body then
    table.insert(cmd, "-d")
    table.insert(cmd, body)
  end

  -- Add URL
  table.insert(cmd, url)

  -- Create unique request ID
  local request_id = tostring(os.time()) .. math.random(1000, 9999)

  local stdout_data = {}
  local stderr_data = {}
  local callback_called = false

  local function safe_callback(response, err)
    if callback_called then return end
    callback_called = true
    vim.schedule(function()
      callback(response, err)
    end)
  end

  local job_id = vim.fn.jobstart(cmd, {
    stdout_buffered = true,
    stderr_buffered = true,
    on_exit = function(_, exit_code)
      active_requests[request_id] = nil

      if exit_code ~= 0 then
        local error_msg = table.concat(stderr_data, "\n"):gsub("%s+$", "")
        safe_callback(nil, "HTTP request failed (exit code: " .. exit_code .. ")" ..
          (error_msg ~= "" and ": " .. error_msg or ""))
        return
      end

      local response_text = table.concat(stdout_data, "\n"):gsub("%s+$", "")
      if response_text == "" then
        safe_callback(nil, "Empty HTTP response")
        return
      end

      local success, result = pcall(vim.json.decode, response_text)
      if not success then
        safe_callback(nil, "Failed to parse JSON response")
        return
      end

      -- Check for API error response
      if result.error then
        safe_callback(nil, "API error: " .. (result.error.message or vim.json.encode(result.error)))
        return
      end

      -- Extract content from Anthropic API response
      if result.content and #result.content > 0 then
        local content = ""
        for _, block in ipairs(result.content) do
          if block.type == "text" then
            content = content .. block.text
          end
        end
        safe_callback(content, nil)
      else
        safe_callback(nil, "No content in API response")
      end
    end,
    on_stdout = function(_, data)
      if data then
        vim.list_extend(stdout_data, data)
      end
    end,
    on_stderr = function(_, data)
      if data then
        vim.list_extend(stderr_data, data)
      end
    end,
  })
  
  if job_id > 0 then
    active_requests[request_id] = job_id
    return request_id
  else
    callback(nil, "Failed to start HTTP request")
    return nil
  end
end

-- Create Claude Code optimized prompt for CLI
local function create_claude_prompt(system_prompt, user_prompt, context)
  local full_prompt = ""
  
  -- Add system context for Claude CLI
  if system_prompt then
    full_prompt = system_prompt .. "\n\n"
  else
    full_prompt = "You are Claude Code, an advanced AI coding assistant. " ..
                 "You excel at writing clean, efficient code, debugging, code review, and providing detailed explanations.\n\n"
  end
  
  -- Add context if provided
  if context and context.file_content then
    full_prompt = full_prompt .. "Current file context:\n```" .. (context.language or "") .. "\n" 
                 .. context.file_content .. "\n```\n\n"
  end
  
  if context and context.selection then
    full_prompt = full_prompt .. "Selected code:\n```" .. (context.language or "") .. "\n" 
                 .. context.selection .. "\n```\n\n"
  end
  
  if context and context.error then
    full_prompt = full_prompt .. "Error details:\n" .. context.error .. "\n\n"
  end
  
  full_prompt = full_prompt .. user_prompt
  
  return full_prompt
end

-- Create HTTP payload for API requests
local function create_http_payload(system_prompt, user_prompt, context)
  local cfg = config.get()
  local system_message = system_prompt or "You are Claude Code, an advanced AI coding assistant."
  
  -- Add context to user prompt
  if context and context.file_content then
    user_prompt = "Context (current file):\n```" .. (context.language or "") .. "\n" 
                 .. context.file_content .. "\n```\n\n" .. user_prompt
  end
  
  if context and context.selection then
    user_prompt = "Selected code:\n```" .. (context.language or "") .. "\n" 
                 .. context.selection .. "\n```\n\n" .. user_prompt
  end
  
  if context and context.error then
    user_prompt = "Error details:\n" .. context.error .. "\n\n" .. user_prompt
  end

  return {
    model = cfg.api.model,
    max_tokens = cfg.api.max_tokens,
    temperature = cfg.api.temperature,
    system = system_message,
    messages = {
      {
        role = "user",
        content = user_prompt
      }
    }
  }
end

-- Main request function (automatically chooses CLI or HTTP)
function M.request(prompt, context, callback)
  local cfg = config.get()
  
  -- Check if we should use CLI or HTTP API
  local use_cli = cfg.api.use_cli
  if use_cli == nil then
    -- Auto-detect: use CLI if available and no API key, otherwise use API key if available
    use_cli = check_claude_cli() and not cfg.api.key
  end
  
  if use_cli then
    -- Use Claude CLI
    local full_prompt = create_claude_prompt(nil, prompt, context)
    return make_claude_cli_request(full_prompt, callback)
  else
    -- Use HTTP API
    if not cfg.api.key then
      callback(nil, "❌ No API key configured and Claude CLI not available.\n\n" ..
               "Options to fix:\n" ..
               "1. Set ANTHROPIC_API_KEY environment variable\n" ..
               "2. Install Claude CLI: 'npm install -g @anthropic-ai/claude-3-cli'\n" ..
               "3. Authenticate CLI: 'claude auth login'")
      return nil
    end
    
    local headers = {
      ["Content-Type"] = "application/json",
      ["x-api-key"] = cfg.api.key,
      ["anthropic-version"] = "2023-06-01"
    }
    
    local payload = create_http_payload(nil, prompt, context)
    local body = vim.json.encode(payload)
    local url = cfg.api.base_url .. "/messages"
    
    return make_http_request(url, headers, body, callback)
  end
end

-- Code completion specific request
function M.complete_code(context, callback)
  if not config.get().features.completion.enabled then
    callback(nil, "Code completion is disabled")
    return
  end
  
  local prompt = config.get().prompts.code_completion .. "\n\n"
  
  if context.before_cursor then
    prompt = prompt .. "Code before cursor:\n```" .. (context.language or "") .. "\n" 
             .. context.before_cursor .. "\n```\n\n"
  end
  
  if context.after_cursor then
    prompt = prompt .. "Code after cursor:\n```" .. (context.language or "") .. "\n" 
             .. context.after_cursor .. "\n```\n\n"
  end
  
  prompt = prompt .. "Provide the most appropriate completion for the code at the cursor position. "
  prompt = prompt .. "Return only the completion code without explanations or markdown formatting."
  
  return M.request(prompt, context, callback)
end

-- Code generation request
function M.generate_code(description, context, callback)
  if not config.get().features.code_writing.enabled then
    callback(nil, "Code generation is disabled")
    return
  end
  
  local prompt = config.get().prompts.code_generation .. "\n\n"
  prompt = prompt .. "Task: " .. description .. "\n\n"
  
  if context.language then
    prompt = prompt .. "Programming language: " .. context.language .. "\n"
  end
  
  if config.get().features.code_writing.include_type_hints then
    prompt = prompt .. "Include type hints where applicable.\n"
  end
  
  if config.get().features.code_writing.include_docstrings then
    prompt = prompt .. "Include comprehensive docstrings/comments.\n"
  end
  
  if config.get().features.code_writing.include_error_handling then
    prompt = prompt .. "Include proper error handling.\n"
  end
  
  return M.request(prompt, context, callback)
end

-- Code explanation request
function M.explain_code(code, context, callback)
  local prompt = config.get().prompts.code_explanation .. "\n\n"
  
  if not code and context.selection then
    code = context.selection
  end
  
  if not code then
    callback(nil, "No code provided for explanation")
    return
  end
  
  -- Don't add code to context again, it will be added by the main request function
  local clean_context = vim.tbl_extend("force", context or {}, { selection = code })
  
  return M.request(prompt, clean_context, callback)
end

-- Debug analysis request
function M.analyze_error(error_message, context, callback)
  if not config.get().features.debugging.enabled then
    callback(nil, "Debugging assistance is disabled")
    return
  end
  
  local prompt = config.get().prompts.debug_analysis .. "\n\n"
  prompt = prompt .. "Error: " .. error_message
  
  local debug_context = vim.tbl_extend("force", context or {}, { error = error_message })
  
  return M.request(prompt, debug_context, callback)
end

-- Code review request
function M.review_code(code, context, callback)
  if not config.get().features.code_review.enabled then
    callback(nil, "Code review is disabled")
    return
  end
  
  local prompt = config.get().prompts.code_review .. "\n\n"
  
  if not code and context.file_content then
    code = context.file_content
  end
  
  if not code then
    callback(nil, "No code provided for review")
    return
  end
  
  -- Check file size limit
  local line_count = select(2, code:gsub('\n', '\n')) + 1
  if line_count > config.get().features.code_review.max_file_size then
    callback(nil, "File too large for review (max " .. config.get().features.code_review.max_file_size .. " lines)")
    return
  end
  
  local review_aspects = {}
  if config.get().features.code_review.check_security then
    table.insert(review_aspects, "security vulnerabilities")
  end
  if config.get().features.code_review.check_performance then
    table.insert(review_aspects, "performance issues")
  end
  if config.get().features.code_review.check_maintainability then
    table.insert(review_aspects, "maintainability concerns")
  end
  if config.get().features.code_review.suggest_patterns then
    table.insert(review_aspects, "design pattern improvements")
  end
  
  if #review_aspects > 0 then
    prompt = prompt .. "Focus on: " .. table.concat(review_aspects, ", ") .. ".\n\n"
  end
  
  local review_context = vim.tbl_extend("force", context or {}, { 
    selection = code,
    file_content = nil -- Don't duplicate the code
  })
  
  return M.request(prompt, review_context, callback)
end

-- Test generation request
function M.generate_tests(code, context, callback)
  if not config.get().features.testing.enabled then
    callback(nil, "Test generation is disabled")
    return
  end
  
  local prompt = config.get().prompts.test_generation .. "\n\n"
  
  if not code and context.selection then
    code = context.selection
  end
  
  if not code then
    callback(nil, "No code provided for test generation")
    return
  end
  
  local test_features = {}
  if config.get().features.testing.generate_edge_cases then
    table.insert(test_features, "edge cases")
  end
  if config.get().features.testing.include_mocks then
    table.insert(test_features, "mock objects where needed")
  end
  
  if #test_features > 0 then
    prompt = prompt .. "Include: " .. table.concat(test_features, ", ") .. ".\n\n"
  end
  
  local test_context = vim.tbl_extend("force", context or {}, { selection = code })
  
  return M.request(prompt, test_context, callback)
end

-- Refactoring suggestions request
function M.suggest_refactoring(code, context, callback)
  if not config.get().features.refactoring.enabled then
    callback(nil, "Refactoring suggestions are disabled")
    return
  end
  
  local prompt = config.get().prompts.refactoring .. "\n\n"
  
  if not code and context.selection then
    code = context.selection
  end
  
  if not code then
    callback(nil, "No code provided for refactoring")
    return
  end
  
  local refactor_context = vim.tbl_extend("force", context or {}, { selection = code })
  
  return M.request(prompt, refactor_context, callback)
end

-- Cancel active requests
function M.cancel_requests()
  for request_id, job_id in pairs(active_requests) do
    vim.fn.jobstop(job_id)
    active_requests[request_id] = nil
  end
end

-- Get active request count
function M.get_active_requests()
  local count = 0
  for _ in pairs(active_requests) do
    count = count + 1
  end
  return count
end

-- Check authentication status
function M.check_auth_status()
  local cfg = config.get()
  local use_cli = cfg.api.use_cli
  if use_cli == nil then
    use_cli = check_claude_cli() and not cfg.api.key
  end
  
  if use_cli then
    local cli_available = check_claude_cli()
    return {
      method = "cli",
      available = cli_available,
      status = cli_available and "Claude CLI available and ready" or
               "Claude CLI not available. Install with 'npm install -g @anthropic-ai/claude-code' and authenticate."
    }
  else
    local has_key = cfg.api.key ~= nil and cfg.api.key ~= ""
    return { 
      method = "api", 
      available = has_key, 
      status = has_key and "✅ API key configured and ready" or 
               "❌ API key not configured. Set ANTHROPIC_API_KEY environment variable."
    }
  end
end

return M