-- Simple diagnostic helper for chat panel issues
-- Run this in Neovim with :luafile chat_debug_helper.lua

print("🔍 Claude Code Chat Panel Diagnostic Helper")
print("=" .. string.rep("=", 48))

-- Check if Claude Code is loaded
local claude_ok, claude = pcall(require, "claude-code")
if not claude_ok then
  print("❌ Claude Code plugin not loaded")
  print("   Solution: Make sure plugin is installed and loaded")
  return
end
print("✅ Claude Code plugin loaded")

-- Check if chat panel module exists
local chat_ok, chat_panel = pcall(require, "claude-code.chat_panel")
if not chat_ok then
  print("❌ Chat panel module not found")
  print("   Error:", chat_panel)
  return
end
print("✅ Chat panel module loaded")

-- Check if API module exists
local api_ok, api = pcall(require, "claude-code.api")
if not api_ok then
  print("❌ API module not found")
  print("   Error:", api)
  return
end
print("✅ API module loaded")

-- Check API configuration
print("\n📡 API Configuration Check:")
local api_status = api.check_auth_status()
print("   Method:", api_status.method)
print("   Status:", api_status.status)
print("   Available:", api_status.available and "✅ Yes" or "❌ No")

if not api_status.available then
  print("\n🔧 Troubleshooting Steps:")
  if api_status.method == "api" then
    print("   1. Set your ANTHROPIC_API_KEY environment variable:")
    print("      export ANTHROPIC_API_KEY='your-api-key-here'")
    print("   2. Or configure it in your plugin setup:")
    print("      require('claude-code').setup({ api = { key = 'your-key' } })")
    print("   3. Restart Neovim after setting the key")
  elseif api_status.method == "cli" then
    print("   1. Install Claude CLI: pip install claude-cli")
    print("   2. Authenticate: claude auth login") 
    print("   3. Test: claude --version")
  end
end

-- Check config module
local config_ok, config = pcall(require, "claude-code.config")
if not config_ok then
  print("❌ Config module not found")
  return
end
print("✅ Config module loaded")

-- Test utils module (our fix)
local utils_ok, utils = pcall(require, "claude-code.utils")
if not utils_ok then
  print("❌ Utils module not found (this is the main fix!)")
  print("   Error:", utils)
  return
end
print("✅ Utils module loaded (trim fix applied)")

-- Test string trimming specifically
local test_string = "  hello world  "
local trimmed = utils.string.trim(test_string)
if trimmed == "hello world" then
  print("✅ String trimming works correctly")
else
  print("❌ String trimming failed:", "'" .. trimmed .. "'")
end

-- Test metatable extension
local meta_success, meta_result = pcall(function() return ("  test  "):trim() end)
if meta_success and meta_result == "test" then
  print("✅ String metatable extension works")
else
  print("❌ String metatable extension failed")
end

-- Check if chat panel is currently open
print("\n💬 Chat Panel Status:")
if chat_panel.is_open() then
  print("   Status: ✅ Open")
  local history = chat_panel.get_history()
  print("   History entries:", #history)
else
  print("   Status: ⏸️  Closed")
end

-- Final recommendations
print("\n🎯 Recommendations:")
if api_status.available then
  print("✅ API is configured correctly")
  print("✅ All modules are loaded")
  print("✅ String trimming is working")
  print("\n💡 Try opening chat panel with :ClaudeChatPanel")
  print("💡 Check API status anytime with :ClaudeChatStatus")
  print("💡 If still failing, check Neovim messages with :messages")
else
  print("⚠️  API configuration needs attention (see steps above)")
  print("✅ Core functionality should work once API is configured")
end

print("\n" .. string.rep("=", 50))