-- Test the specific issue that was causing chat panel failures
print("🔧 Testing the specific trim() fix...")

-- Test the utils module with string metatable extension
local function test_utils()
  -- Mock minimal vim object
  _G.vim = {}
  
  local utils = dofile("lua/claude-code/utils.lua")
  
  -- Test 1: Direct function call
  local direct_result = utils.string.trim("  test message  ")
  print("Direct utils.string.trim result:", "'" .. direct_result .. "'")
  assert(direct_result == "test message", "Direct function call failed")
  
  -- Test 2: String metatable extension (this was failing before)
  local metatable_result = ("  test message  "):trim()
  print("String metatable :trim() result:", "'" .. metatable_result .. "'")
  assert(metatable_result == "test message", "Metatable extension failed")
  
  -- Test 3: The exact scenario from chat_panel.lua
  local test_input = "💬 Message: hello world"
  local processed = test_input:gsub("^💬 Message: ", "")
  local final_result = processed:trim()
  print("Chat panel scenario result:", "'" .. final_result .. "'")
  assert(final_result == "hello world", "Chat panel scenario failed")
  
  -- Test 4: Edge cases
  assert((""):trim() == "", "Empty string failed")
  assert(("   "):trim() == "", "Whitespace-only string failed")
  assert(("no spaces"):trim() == "no spaces", "No-trim case failed")
  
  return true
end

-- Run the test
local success, error_msg = pcall(test_utils)

if success then
  print("✅ All trim functionality tests passed!")
  print("✅ The chat panel should now work correctly for sending messages")
  print("✅ The :trim() method error has been fixed")
else
  print("❌ Test failed:", error_msg)
  os.exit(1)
end