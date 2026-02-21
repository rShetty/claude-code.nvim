-- Test helpers for Claude Code Neovim Plugin
local M = {}

-- Mock vim API for testing
local vim_mock = {
  api = {
    nvim_create_user_command = function() end,
    nvim_create_buf = function() return 1 end,
    nvim_buf_set_option = function() end,
    nvim_win_get_cursor = function() return {1, 0} end,
    nvim_get_current_buf = function() return 1 end,
    nvim_buf_get_lines = function() return {"test line"} end,
    nvim_buf_set_lines = function() end,
    nvim_buf_get_name = function() return "test.lua" end,
    nvim_buf_get_option = function() return "lua" end,
    nvim_create_autocmd = function() end,
    nvim_open_win = function() return 1001 end,
    nvim_win_close = function() end,
    nvim_win_is_valid = function() return true end,
    nvim_win_set_option = function() end,
    nvim_buf_add_highlight = function() end,
  },
  fn = {
    expand = function() return "test_var" end,
    input = function() return "test_input" end,
    getqflist = function() return {} end,
    getreg = function() return "" end,
    jobstart = function() return 1234 end,
    chansend = function() end,
    chanclose = function() end,
    jobstop = function() end,
    getpos = function() return {0, 1, 1, 0} end,
    mode = function() return "n" end,
    fnamemodify = function() return "test.lua" end,
    stdpath = function() return "/tmp" end,
  },
  keymap = {
    set = function() end,
  },
  notify = function() end,
  log = {
    levels = {
      INFO = 1,
      WARN = 2,
      ERROR = 3,
    }
  },
  env = {
    ANTHROPIC_API_KEY = "test-key"
  },
  ui = {
    input = function(opts, callback)
      if callback then callback("test input") end
    end,
    select = function(items, opts, callback)
      if callback then callback(items[1], 1) end
    end,
  },
  split = function(str)
    return {str}
  end,
  tbl_extend = function(behavior, ...)
    local result = {}
    local tables = {...}
    for _, t in ipairs(tables) do
      if type(t) == "table" then
        for k, v in pairs(t) do
          result[k] = v
        end
      end
    end
    return result
  end,
  tbl_deep_extend = function(behavior, ...)
    local function deep_extend(t1, t2)
      local result = {}
      for k, v in pairs(t1 or {}) do
        result[k] = v
      end
      for k, v in pairs(t2 or {}) do
        if type(v) == "table" and type(result[k]) == "table" then
          result[k] = deep_extend(result[k], v)
        else
          result[k] = v
        end
      end
      return result
    end
    
    local tables = {...}
    local result = tables[1] or {}
    for i = 2, #tables do
      result = deep_extend(result, tables[i])
    end
    return result
  end,
  deepcopy = function(t)
    if type(t) ~= "table" then return t end
    local result = {}
    for k, v in pairs(t) do
      result[k] = vim.deepcopy(v)
    end
    return result
  end,
  loop = {
    new_timer = function()
      return {
        start = function() end,
        stop = function() end,
        close = function() end,
      }
    end
  },
  schedule_wrap = function(fn) return fn end,
  defer_fn = function(fn, delay) fn() end,
  schedule = function(fn) fn() end,
  json = {
    encode = function(data) return "{}" end,
    decode = function(str) return {} end,
  },
  o = {
    columns = 100,
    lines = 50,
  },
}

-- Set up vim global for testing
function M.setup_vim_mock()
  _G.vim = vim_mock
  return vim_mock
end

-- Create a test buffer context
function M.create_test_context()
  return {
    filename = "test.lua",
    filetype = "lua", 
    language = "lua",
    file_content = "function test()\n  return true\nend",
    selection = "return true",
    cursor_line = 2,
    cursor_col = 2,
    before_cursor = "function test()\n",
    after_cursor = "\nend",
    start_line = 2,
    end_line = 2,
  }
end

-- Mock API responses
function M.create_mock_api()
  return {
    request = function(prompt, context, callback)
      local response = "Mock AI response for: " .. (prompt or "")
      callback(response, nil)
    end,
    generate_code = function(description, context, callback)
      local code = "-- Generated code for: " .. description .. "\nfunction generated_function()\n  -- Implementation here\nend"
      callback(code, nil)
    end,
    explain_code = function(code, context, callback)
      local explanation = "This code does the following:\\n1. It defines a function\\n2. It returns a value"
      callback(explanation, nil)
    end,
    analyze_error = function(error_msg, context, callback)
      local analysis = "Error analysis for: " .. error_msg .. "\\nSuggested fix: Check line numbers"
      callback(analysis, nil)
    end,
    review_code = function(code, context, callback)
      local review = "Code review results:\\n- Code looks good\\n- Consider adding error handling"
      callback(review, nil)
    end,
    generate_tests = function(code, context, callback)
      local tests = "-- Generated tests\\ndescribe('test', function()\\n  it('should work', function()\\n    assert.equals(true, test())\\n  end)\\nend)"
      callback(tests, nil)
    end,
    suggest_refactoring = function(code, context, callback)
      local suggestions = "Refactoring suggestions:\\n1. Extract method\\n2. Rename variables"
      callback(suggestions, nil)
    end,
    cancel_requests = function() end,
    get_active_requests = function() return 0 end,
    check_auth_status = function()
      return {
        method = "api",
        available = true,
        status = "✅ Test API configured"
      }
    end,
  }
end

-- Mock UI functions  
function M.create_mock_ui()
  return {
    show_loading = function(title, message)
      return 9999 -- mock window ID
    end,
    hide_loading = function() end,
    show_response = function() end,
    show_error = function() end,
    show_success = function() end,
    input_dialog = function(prompt, callback, opts)
      if callback then callback("test input") end
    end,
    select_dialog = function(items, callback, opts)
      if callback then callback(items[1]) end
    end,
    get_current_context = function()
      return M.create_test_context()
    end,
    close_window = function() end,
    close_all_windows = function() end,
    cleanup = function() end,
    apply_code_suggestion = function() end,
  }
end

-- Mock config
function M.create_mock_config()
  return {
    setup = function() end,
    get = function()
      return {
        api = {
          key = "test-key",
          model = "claude-3-5-sonnet-20241022",
          base_url = "https://api.anthropic.com/v1",
          max_tokens = 4096,
          temperature = 0.1,
          timeout = 30000,
          use_cli = false,
        },
        features = {
          completion = { enabled = true, max_context_lines = 100 },
          code_writing = { enabled = true },
          debugging = { enabled = true },
          code_review = { enabled = true, max_file_size = 10000 },
          testing = { enabled = true },
          refactoring = { enabled = true },
        },
        ui = {
          float_border = "rounded",
          float_width = 0.8,
          float_height = 0.6,
          progress_indicator = true,
          syntax_highlighting = true,
          auto_close_delay = 5000,
        },
        keymaps = {
          commands = {
            write_function = "<leader>cw",
            implement_todo = "<leader>ci",
          }
        },
        prompts = {
          code_completion = "Complete this code:",
          code_generation = "Generate code:",
          code_explanation = "Explain this code:",
          debug_analysis = "Debug this error:",
          code_review = "Review this code:",
          test_generation = "Generate tests:",
          refactoring = "Suggest refactoring:",
        },
      }
    end,
    update = function() end,
    validate = function() end,
    setup_keymaps = function() end,
  }
end

-- Helper to capture function calls
function M.create_spy()
  local calls = {}
  return {
    fn = function(...)
      table.insert(calls, {...})
    end,
    calls = calls,
    call_count = function() return #calls end,
    was_called = function() return #calls > 0 end,
    was_called_with = function(...)
      local args = {...}
      for _, call in ipairs(calls) do
        local match = true
        for i, arg in ipairs(args) do
          if call[i] ~= arg then
            match = false
            break
          end
        end
        if match then return true end
      end
      return false
    end,
  }
end

-- Wait for async operations (mock)
function M.wait_for_async(timeout)
  timeout = timeout or 100
  -- In real tests, this might use vim.wait or similar
  -- For now, just execute immediately
  return true
end

-- Load test fixtures
function M.load_fixture(name)
  local fixture_path = "tests/fixtures/" .. name .. ".lua"
  local file = io.open(fixture_path, "r")
  if not file then
    return nil, "Fixture not found: " .. name
  end
  local content = file:read("*all")
  file:close()
  return content
end

return M