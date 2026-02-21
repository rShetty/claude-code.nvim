#!/usr/bin/env lua
-- Simple test runner to verify our fixes work
print("🧪 Testing Claude Code fixes...")

-- Test 1: Utils module loading and string operations
print("\n📦 Test 1: Utils module")
local success, utils = pcall(function()
  -- Mock the vim object for testing
  _G.vim = {}
  
  -- Mock package.loaded to avoid module dependencies
  package.loaded["claude-code.config"] = {}
  package.loaded["claude-code.api"] = {}
  package.loaded["claude-code.ui"] = {}
  
  return dofile("lua/claude-code/utils.lua")
end)

if success then
  print("✅ Utils module loaded successfully")
  
  -- Test string trimming
  local test_cases = {
    {"  hello  ", "hello"},
    {"\t\nworld\n\t", "world"},
    {"test", "test"},
    {"   ", ""},
    {"", ""},
    {nil, ""}
  }
  
  for i, case in ipairs(test_cases) do
    local input, expected = case[1], case[2]
    local result = utils.string.trim(input)
    if result == expected then
      print(string.format("✅ Trim test %d: '%s' -> '%s'", i, tostring(input), result))
    else
      print(string.format("❌ Trim test %d failed: expected '%s', got '%s'", i, expected, result))
    end
  end
  
  -- Test string metatable extension
  if pcall(function() return ("  hello  "):trim() end) then
    local result = ("  hello  "):trim()
    if result == "hello" then
      print("✅ String metatable extension works")
    else
      print("❌ String metatable extension failed")
    end
  else
    print("❌ String metatable extension not working")
  end
  
  -- Test validation utilities
  if utils.validate.non_empty_string("hello") and 
     not utils.validate.non_empty_string("") and
     not utils.validate.non_empty_string(nil) then
    print("✅ Validation utilities work")
  else
    print("❌ Validation utilities failed")
  end
else
  print("❌ Utils module failed to load:", utils)
end

-- Test 2: Chat panel can be loaded without errors
print("\n💬 Test 2: Chat panel module")
local chat_success, chat_error = pcall(function()
  -- Enhanced vim mock for chat panel
  _G.vim = {
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
      nvim_buf_get_lines = function() return {"💬 Message: test"} end,
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
    },
    cmd = function() end,
    split = function(str, sep) return {str} end,
    tbl_deep_extend = function(mode, t1, t2)
      local result = {}
      for k, v in pairs(t1 or {}) do result[k] = v end
      for k, v in pairs(t2 or {}) do result[k] = v end
      return result
    end,
    deepcopy = function(t) return t end,
    notify = function() end,
    log = { levels = { INFO = 1, ERROR = 2 } },
    defer_fn = function() end,
  }
  
  -- Mock dependencies
  package.loaded["claude-code.config"] = {
    get = function()
      return {
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
  
  package.loaded["claude-code.api"] = {
    request = function(message, context, callback)
      callback("Test response", nil)
      return "test-request-id"
    end
  }
  
  package.loaded["claude-code.ui"] = {
    get_current_context = function()
      return {
        filename = "/test/file.lua",
        filetype = "lua",
        file_content = "print('hello')",
        selection = nil,
      }
    end
  }
  
  -- Load chat panel
  local chat_panel = dofile("lua/claude-code/chat_panel.lua")
  
  -- Test basic functionality
  chat_panel.setup({})
  
  -- Test that we can call functions without errors
  assert(type(chat_panel.is_open) == "function")
  assert(type(chat_panel.get_history) == "function")
  assert(type(chat_panel.clear_history) == "function")
  
  -- Test history operations
  local initial_history = chat_panel.get_history()
  assert(type(initial_history) == "table")
  assert(#initial_history == 0)
  
  chat_panel.clear_history()
  
  return true
end)

if chat_success then
  print("✅ Chat panel module loaded and basic functions work")
else
  print("❌ Chat panel module failed:", chat_error)
end

-- Test 3: Init module can use utils
print("\n🚀 Test 3: Init module string operations")
local init_success, init_error = pcall(function()
  -- Mock additional dependencies for init module
  package.loaded["claude-code.git"] = {}
  package.loaded["claude-code.file_watcher"] = {}
  package.loaded["claude-code.terminal"] = {}
  package.loaded["claude-code.which_key"] = {}
  package.loaded["claude-code.chat_panel"] = { cleanup = function() end }
  
  -- Load and test basic functionality
  local claude_init = dofile("lua/claude-code/init.lua")
  
  -- Check that required functions exist
  assert(type(claude_init.setup) == "function")
  assert(type(claude_init.cleanup_all_modules) == "function")
  
  return true
end)

if init_success then
  print("✅ Init module loaded successfully with utils dependency")
else
  print("❌ Init module failed:", init_error)
end

-- Test 4: Message trimming simulation
print("\n✂️  Test 4: Message processing simulation")
local message_test_success, message_test_error = pcall(function()
  -- Test the exact scenario that was failing
  local test_message = "💬 Message: hello world"
  local processed = test_message:gsub("^💬 Message: ", "")
  
  if not utils then
    error("Utils not available from previous test")
  end
  
  local trimmed = utils.string.trim(processed)
  
  if trimmed == "hello world" then
    print("✅ Message processing works correctly")
    return true
  else
    error("Expected 'hello world', got '" .. tostring(trimmed) .. "'")
  end
end)

if not message_test_success then
  print("❌ Message processing failed:", message_test_error)
end

-- Summary
print("\n📊 Test Summary:")
local total_tests = 4
local passed_tests = 0

if success then passed_tests = passed_tests + 1 end
if chat_success then passed_tests = passed_tests + 1 end  
if init_success then passed_tests = passed_tests + 1 end
if message_test_success then passed_tests = passed_tests + 1 end

print(string.format("Passed: %d/%d tests", passed_tests, total_tests))

if passed_tests == total_tests then
  print("🎉 All tests passed! The fixes should work correctly.")
  os.exit(0)
else
  print("⚠️  Some tests failed. Please review the errors above.")
  os.exit(1)
end