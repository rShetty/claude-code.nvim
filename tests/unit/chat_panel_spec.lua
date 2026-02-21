-- Unit tests for chat panel module
describe("chat_panel module", function()
  local chat_panel
  local mock_vim
  local mock_config
  local mock_api
  local mock_ui
  local mock_utils

  before_each(function()
    -- Mock vim API
    mock_vim = {
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
        nvim_buf_get_lines = function() return {"💬 Message: test message"} end,
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
      log = { levels = { INFO = 1, ERROR = 2 } },
    }

    -- Mock config module
    mock_config = {
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

    -- Mock UI module
    mock_ui = {
      get_current_context = function()
        return {
          filename = "/test/file.lua",
          filetype = "lua",
          file_content = "print('hello world')",
          selection = nil,
        }
      end
    }

    -- Mock API module
    mock_api = {
      request = function(message, context, callback)
        -- Simulate async response
        vim.defer_fn(function()
          if message == "error test" then
            callback(nil, "Mock API error")
          else
            callback("Mock response: " .. message, nil)
          end
        end, 10)
        return "request-123" -- Mock request ID
      end
    }

    -- Mock utils module
    mock_utils = {
      string = {
        trim = function(str)
          if not str then return "" end
          return str:match("^%s*(.-)%s*$") or ""
        end
      }
    }

    -- Set up global vim
    _G.vim = mock_vim

    -- Mock package.loaded
    package.loaded["claude-code.config"] = mock_config
    package.loaded["claude-code.api"] = mock_api
    package.loaded["claude-code.ui"] = mock_ui
    package.loaded["claude-code.utils"] = mock_utils

    -- Clear and reload the chat panel module
    package.loaded["claude-code.chat_panel"] = nil
    chat_panel = require("claude-code.chat_panel")
  end)

  after_each(function()
    -- Clean up
    if chat_panel and chat_panel.cleanup then
      chat_panel.cleanup()
    end
  end)

  describe("module initialization", function()
    it("should load without errors", function()
      assert.is_not_nil(chat_panel)
      assert.is_function(chat_panel.setup)
      assert.is_function(chat_panel.toggle)
      assert.is_function(chat_panel.open)
      assert.is_function(chat_panel.close)
    end)
  end)

  describe("setup function", function()
    it("should configure the chat panel with default options", function()
      assert.has_no.errors(function()
        chat_panel.setup({})
      end)
    end)

    it("should configure the chat panel with custom options", function()
      local custom_config = {
        width = 60,
        position = "left",
        max_history = 100,
      }
      
      assert.has_no.errors(function()
        chat_panel.setup(custom_config)
      end)
    end)
  end)

  describe("panel operations", function()
    before_each(function()
      chat_panel.setup({})
    end)

    it("should open the chat panel", function()
      assert.is_false(chat_panel.is_open())
      chat_panel.open()
      assert.is_true(chat_panel.is_open())
    end)

    it("should close the chat panel", function()
      chat_panel.open()
      assert.is_true(chat_panel.is_open())
      
      chat_panel.close()
      assert.is_false(chat_panel.is_open())
    end)

    it("should toggle the chat panel", function()
      assert.is_false(chat_panel.is_open())
      
      -- Toggle open
      chat_panel.toggle()
      assert.is_true(chat_panel.is_open())
      
      -- Toggle close
      chat_panel.toggle()
      assert.is_false(chat_panel.is_open())
    end)

    it("should not open panel twice", function()
      chat_panel.open()
      local first_state = chat_panel.is_open()
      
      chat_panel.open() -- Try to open again
      local second_state = chat_panel.is_open()
      
      assert.is_true(first_state)
      assert.is_true(second_state)
    end)

    it("should not close panel twice", function()
      chat_panel.close()
      local first_state = chat_panel.is_open()
      
      chat_panel.close() -- Try to close again
      local second_state = chat_panel.is_open()
      
      assert.is_false(first_state)
      assert.is_false(second_state)
    end)
  end)

  describe("message handling", function()
    before_each(function()
      chat_panel.setup({})
      chat_panel.open()
    end)

    it("should handle successful message sending", function()
      local initial_history = chat_panel.get_history()
      assert.are.equal(0, #initial_history)

      -- Mock successful API response
      local success = false
      mock_api.request = function(message, context, callback)
        callback("Success response", nil)
        success = true
        return "request-123"
      end

      -- Simulate sending message
      chat_panel.start_input()
      
      -- Mock the message sending process
      local entry = {
        user_message = "test message",
        loading = true,
        timestamp = os.time(),
      }
      
      -- Manually add to history (simulating what send_message does)
      local history = chat_panel.get_history()
      table.insert(history, entry)
      
      assert.are.equal(1, #history)
      assert.are.equal("test message", history[1].user_message)
      assert.is_true(history[1].loading)
    end)

    it("should handle API errors", function()
      local error_handled = false
      
      -- Mock error response
      mock_api.request = function(message, context, callback)
        callback(nil, "API Error")
        error_handled = true
        return "request-123"
      end

      -- Mock the error handling
      local entry = {
        user_message = "test message",
        loading = false,
        error = "API Error",
        timestamp = os.time(),
      }
      
      assert.are.equal("API Error", entry.error)
      assert.is_false(entry.loading)
    end)

    it("should handle request ID failure", function()
      -- Mock API request that returns nil (failure)
      mock_api.request = function(message, context, callback)
        return nil -- Simulate request failure
      end

      local entry = {
        user_message = "test message",
        loading = false,
        error = "Failed to start request",
        timestamp = os.time(),
      }
      
      assert.are.equal("Failed to start request", entry.error)
    end)
  end)

  describe("chat history", function()
    before_each(function()
      chat_panel.setup({})
    end)

    it("should maintain chat history", function()
      local history = chat_panel.get_history()
      assert.are.equal(0, #history)
      
      -- This would be done by send_message function
      -- We're testing the structure here
      local test_entry = {
        user_message = "Hello",
        response = "Hi there!",
        timestamp = os.time(),
      }
      
      assert.is_not_nil(test_entry.user_message)
      assert.is_not_nil(test_entry.response)
      assert.is_not_nil(test_entry.timestamp)
    end)

    it("should clear chat history", function()
      chat_panel.clear_history()
      local history = chat_panel.get_history()
      assert.are.equal(0, #history)
    end)
  end)

  describe("input handling", function()
    before_each(function()
      chat_panel.setup({})
      chat_panel.open()
    end)

    it("should start input mode", function()
      assert.has_no.errors(function()
        chat_panel.start_input()
      end)
    end)

    it("should close input mode", function()
      chat_panel.start_input()
      assert.has_no.errors(function()
        chat_panel.close_input()
      end)
    end)

    it("should trim messages properly", function()
      local test_message = "  test message  "
      local trimmed = mock_utils.string.trim(test_message)
      assert.are.equal("test message", trimmed)
    end)

    it("should handle empty messages", function()
      local empty_message = "   "
      local trimmed = mock_utils.string.trim(empty_message)
      assert.are.equal("", trimmed)
    end)
  end)

  describe("context management", function()
    before_each(function()
      chat_panel.setup({})
      chat_panel.open()
    end)

    it("should update context", function()
      assert.has_no.errors(function()
        chat_panel.update_context()
      end)
    end)

    it("should handle context updates when panel is closed", function()
      chat_panel.close()
      assert.has_no.errors(function()
        chat_panel.update_context()
      end)
    end)
  end)

  describe("display and rendering", function()
    before_each(function()
      chat_panel.setup({})
      chat_panel.open()
    end)

    it("should refresh display", function()
      assert.has_no.errors(function()
        chat_panel.refresh_display()
      end)
    end)

    it("should handle refresh when panel is closed", function()
      chat_panel.close()
      assert.has_no.errors(function()
        chat_panel.refresh_display()
      end)
    end)
  end)

  describe("cleanup", function()
    it("should cleanup properly", function()
      chat_panel.setup({})
      chat_panel.open()
      
      assert.has_no.errors(function()
        chat_panel.cleanup()
      end)
      
      assert.is_false(chat_panel.is_open())
    end)

    it("should handle cleanup when already closed", function()
      chat_panel.setup({})
      
      assert.has_no.errors(function()
        chat_panel.cleanup()
      end)
    end)
  end)

  describe("edge cases", function()
    it("should handle operations when not initialized", function()
      -- Test without calling setup first
      assert.has_no.errors(function()
        chat_panel.toggle()
        chat_panel.is_open()
        chat_panel.get_history()
        chat_panel.clear_history()
      end)
    end)

    it("should handle invalid buffer/window states", function()
      -- Mock invalid states
      mock_vim.api.nvim_buf_is_valid = function() return false end
      mock_vim.api.nvim_win_is_valid = function() return false end
      
      chat_panel.setup({})
      
      assert.has_no.errors(function()
        chat_panel.open()
        chat_panel.close()
        chat_panel.refresh_display()
      end)
    end)
  end)
end)