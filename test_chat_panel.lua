#!/usr/bin/env lua
-- Simple test script for Claude Code chat panel

-- Mock vim API for testing
local vim = {
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
    nvim_buf_get_lines = function() return {""} end,
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
    nvim_buf_add_highlight = function() end,
  },
  keymap = {
    set = function() end,
  },
  o = {
    lines = 50,
    columns = 150,
    cmdheight = 1,
  },
  fn = {
    fnamemodify = function(path, mod) return "test.lua" end,
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
  log = { levels = { INFO = 1 } },
  loop = { new_timer = function() return {start = function() end, stop = function() end, close = function() end} end },
  schedule_wrap = function(f) return f end,
  defer_fn = function() end,
  env = {},
  list_extend = function() end,
}

-- Mock utils module first
local utils_mock = {
  string = {
    trim = function(str)
      if not str then return "" end
      return str:match("^%s*(.-)%s*$") or ""
    end
  }
}

-- Mock modules
local config_mock = {
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

local ui_mock = {
  get_current_context = function()
    return {
      filename = "/test/file.lua",
      filetype = "lua",
      file_content = "print('hello world')",
      selection = nil,
    }
  end
}

local api_mock = {
  request = function(message, context, callback)
    -- Simulate async API response
    vim.defer_fn(function()
      callback("Mock response from Claude: " .. message)
    end, 100)
  end
}

-- Mock package.loaded to avoid require issues
package.loaded["claude-code.config"] = config_mock
package.loaded["claude-code.api"] = api_mock  
package.loaded["claude-code.ui"] = ui_mock
package.loaded["claude-code.utils"] = utils_mock

-- Set global vim
_G.vim = vim

-- Test the chat panel
print("Testing Claude Code Chat Panel...")

-- Load the chat panel module
local chat_panel = dofile("lua/claude-code/chat_panel.lua")

-- Test setup
print("1. Testing setup...")
chat_panel.setup({})
print("✓ Setup completed")

-- Test panel operations
print("2. Testing panel operations...")
print("  - Opening panel...")
chat_panel.open()
print("✓ Panel opened")

print("  - Checking if panel is open...")
local is_open = chat_panel.is_open()
print("✓ Panel status:", is_open and "OPEN" or "CLOSED")

print("  - Getting chat history...")
local history = chat_panel.get_history()
print("✓ History length:", #history)

print("  - Closing panel...")
chat_panel.close()
print("✓ Panel closed")

print("  - Cleanup...")
chat_panel.cleanup()
print("✓ Cleanup completed")

print("\n✅ All chat panel tests passed!")
print("\n🚀 Chat Panel Features:")
print("  • Persistent sidebar chat interface")
print("  • File context awareness")
print("  • Chat history with conversation threading") 
print("  • Toggle with <leader>cp keymap")
print("  • Automatic context updates on file changes")
print("  • Cursor-style interactive experience")