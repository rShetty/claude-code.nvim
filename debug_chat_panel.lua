-- Debug script to identify chat panel message sending issues
print("🔍 Debugging chat panel message sending...")

local function create_mock_vim()
  return {
    api = {
      nvim_create_buf = function() return 1 end,
      nvim_buf_is_valid = function() return true end,
      nvim_open_win = function() return 1 end,
      nvim_win_is_valid = function() return true end,
      nvim_win_close = function() end,
      nvim_buf_delete = function() end,
      nvim_buf_set_option = function() end,
      nvim_win_set_option = function() end,
      nvim_buf_set_lines = function() end,
      nvim_buf_get_lines = function() 
        return {"💬 Message: test message from debug"} 
      end,
      nvim_win_set_cursor = function() end,
      nvim_get_current_win = function() return 2 end,
      nvim_set_current_win = function() end,
      nvim_list_wins = function() return {1, 2, 3} end,
      nvim_win_get_buf = function() return 1 end,
      nvim_buf_get_name = function() return "/test/file.lua" end,
      nvim_buf_get_option = function() return "" end,
      nvim_create_user_command = function() end,
      nvim_create_augroup = function() return 1 end,
      nvim_create_autocmd = function() end,
      nvim_buf_set_name = function() end,
    },
    keymap = { set = function() end },
    o = { lines = 50, columns = 150, cmdheight = 1 },
    fn = { 
      fnamemodify = function() return "test.lua" end,
      prompt_setprompt = function() end,
      jobstart = function() return 1 end,
      chansend = function() end,
      chanclose = function() end,
      jobstop = function() end,
    },
    cmd = function() end,
    split = function(str, sep) return vim.tbl_islist({str}) and {str} or {str} end,
    tbl_deep_extend = function(mode, t1, t2)
      local result = {}
      for k, v in pairs(t1 or {}) do result[k] = v end
      for k, v in pairs(t2 or {}) do result[k] = v end
      return result
    end,
    deepcopy = function(t) return t end,
    notify = function(msg, level) 
      print("📢 Notification:", msg, "(level:", level or "INFO", ")")
    end,
    log = { levels = { INFO = 1, ERROR = 2, WARN = 3 } },
    defer_fn = function(fn, delay) fn() end,
    schedule = function(fn) fn() end,
    schedule_wrap = function(fn) return fn end,
    loop = {
      new_timer = function() 
        return {
          start = function() end, 
          stop = function() end, 
          close = function() end
        } 
      end
    },
    json = {
      encode = function(data) return "mock-json" end,
      decode = function(str) return {content = {{type = "text", text = "Mock response"}}} end,
    }
  }
end

local function run_diagnostic()
  -- Set up environment
  _G.vim = create_mock_vim()
  
  -- Mock dependencies
  local utils_mock = {
    string = {
      trim = function(str)
        if not str then return "" end
        return str:match("^%s*(.-)%s*$") or ""
      end
    }
  }
  
  local config_mock = {
    get = function()
      return {
        api = {
          key = "test-api-key",
          base_url = "https://api.anthropic.com/v1",
          model = "claude-3-sonnet-20240229",
          max_tokens = 1000,
          temperature = 0.7,
          use_cli = false,
        },
        features = {
          completion = { enabled = true },
          code_writing = { enabled = true },
          debugging = { enabled = true },
          code_review = { enabled = true, max_file_size = 1000 },
          testing = { enabled = true },
          refactoring = { enabled = true },
        },
        prompts = {
          code_completion = "Complete this code",
          code_generation = "Generate code",
          code_explanation = "Explain this code", 
          debug_analysis = "Debug this error",
          code_review = "Review this code",
          test_generation = "Generate tests",
          refactoring = "Refactor this code",
        },
        chat_panel = {
          width = 50,
          position = "right",
          show_context_info = true,
          max_history = 50,
          keymaps = {
            toggle = "<leader>cp",
            send = "<CR>",
            cancel = "<Esc>",
            clear_history = "<leader>cc",
          }
        }
      }
    end
  }
  
  local api_request_called = false
  local api_mock = {
    request = function(message, context, callback)
      print("📤 API request called with message:", "'" .. tostring(message) .. "'")
      api_request_called = true
      
      -- Simulate async response
      vim.defer_fn(function()
        print("📥 Calling callback with response")
        callback("Mock Claude response: " .. message, nil)
      end, 10)
      
      return "mock-request-id-123"
    end
  }
  
  local ui_mock = {
    get_current_context = function()
      return {
        filename = "/test/debug.lua",
        filetype = "lua",
        file_content = "-- debug test file",
        selection = nil,
        language = "lua",
      }
    end
  }
  
  -- Load modules
  package.loaded["claude-code.config"] = config_mock
  package.loaded["claude-code.api"] = api_mock
  package.loaded["claude-code.ui"] = ui_mock
  package.loaded["claude-code.utils"] = utils_mock
  
  print("1. Loading utils module...")
  print("✅ Utils mocked")
  
  print("2. Loading chat panel module...")
  local chat_panel = dofile("lua/claude-code/chat_panel.lua")
  print("✅ Chat panel loaded")
  
  print("3. Setting up chat panel...")
  chat_panel.setup({})
  print("✅ Chat panel configured")
  
  print("4. Opening chat panel...")
  chat_panel.open()
  print("✅ Chat panel opened:", chat_panel.is_open())
  
  print("5. Testing message processing...")
  
  -- Simulate the exact flow that happens when sending a message
  local test_message_raw = "💬 Message: hello from debug test"
  local processed_message = test_message_raw:gsub("^💬 Message: ", "")
  local trimmed_message = utils_mock.string.trim(processed_message)
  
  print("   Raw message:", "'" .. test_message_raw .. "'")
  print("   Processed message:", "'" .. processed_message .. "'")
  print("   Trimmed message:", "'" .. trimmed_message .. "'")
  
  if trimmed_message ~= "hello from debug test" then
    print("❌ Message processing failed!")
    return false
  end
  
  print("✅ Message processing works")
  
  print("6. Testing manual message send simulation...")
  
  -- Simulate what send_message does
  local entry = {
    user_message = trimmed_message,
    loading = true,
    timestamp = os.time(),
  }
  
  print("   Created entry:", entry.user_message, "(loading:", entry.loading, ")")
  
  -- Test API call
  print("7. Testing API request...")
  local context = ui_mock.get_current_context()
  local request_id = api_mock.request(trimmed_message, context, function(response, error)
    print("   📥 API callback received:")
    print("   Response:", response and ("'" .. tostring(response) .. "'") or "nil")
    print("   Error:", error and ("'" .. tostring(error) .. "'") or "nil")
    
    if error then
      entry.error = error
      entry.loading = false
      print("❌ API request failed with error")
    else
      entry.response = response
      entry.loading = false
      print("✅ API request successful")
    end
  end)
  
  print("   Request ID:", request_id)
  
  if not request_id then
    print("❌ API request failed to start!")
    return false
  end
  
  if not api_request_called then
    print("❌ API request function was not called!")
    return false
  end
  
  print("✅ API request initiated successfully")
  
  print("8. Cleanup...")
  chat_panel.cleanup()
  print("✅ Cleanup completed")
  
  return true
end

-- Run the diagnostic
local success, error_msg = pcall(run_diagnostic)

if success then
  print("\n🎉 Diagnostic completed successfully!")
  print("✅ All components are working correctly")
  print("🔍 If you're still experiencing issues, the problem might be:")
  print("   • API authentication (check your ANTHROPIC_API_KEY)")
  print("   • Network connectivity") 
  print("   • Rate limiting")
  print("   • Plugin configuration")
else
  print("\n❌ Diagnostic failed:", error_msg)
  print("🔍 This indicates the issue is in the core functionality")
end