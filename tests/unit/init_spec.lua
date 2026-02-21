-- Unit tests for claudeai.init module
local helpers = require('tests.helpers')

describe("claudeai.init", function()
  local init_module
  local mock_config, mock_api, mock_ui
  
  before_each(function()
    helpers.setup_vim_mock()
    
    -- Create mocks
    mock_config = helpers.create_mock_config()
    mock_api = helpers.create_mock_api()
    mock_ui = helpers.create_mock_ui()
    
    -- Mock the requires
    package.preload['claudeai.config'] = function() return mock_config end
    package.preload['claudeai.api'] = function() return mock_api end
    package.preload['claudeai.ui'] = function() return mock_ui end
    
    -- Reset package cache
    package.loaded['claudeai.init'] = nil
    init_module = require('claudeai.init')
  end)
  
  after_each(function()
    -- Clean up
    package.loaded['claudeai.init'] = nil
    package.preload['claudeai.config'] = nil
    package.preload['claudeai.api'] = nil  
    package.preload['claudeai.ui'] = nil
  end)

  describe("setup", function()
    it("should initialize the plugin only once", function()
      local setup_spy = helpers.create_spy()
      mock_config.setup = setup_spy.fn
      
      init_module.setup({})
      init_module.setup({}) -- Second call
      
      assert.equals(1, setup_spy.call_count())
      assert.is_true(init_module.initialized)
    end)
    
    it("should call config setup with user config", function()
      local setup_spy = helpers.create_spy()
      mock_config.setup = setup_spy.fn
      
      local user_config = { api = { key = "test-key" } }
      init_module.setup(user_config)
      
      assert.is_true(setup_spy.was_called_with(user_config))
    end)
    
    it("should register all commands", function()
      local command_spy = helpers.create_spy()
      vim.api.nvim_create_user_command = command_spy.fn
      
      init_module.setup({})\n      
      -- Should register many commands
      assert.is_true(command_spy.call_count() > 10)
      
      -- Check specific commands are registered
      assert.is_true(command_spy.was_called_with(\"ClaudeWriteFunction\", init_module.write_function, {desc = \"Generate function from description using Claude Code\", nargs = \"?\"}))
      assert.is_true(command_spy.was_called_with(\"ClaudeExplainCode\", init_module.explain_code, {desc = \"Explain code using Claude Code\", range = true}))
    end)
    
    it("should create autocommands", function()
      local autocmd_spy = helpers.create_spy()
      vim.api.nvim_create_autocmd = autocmd_spy.fn
      
      init_module.setup({})
      
      -- Should create VimLeavePre autocmd
      assert.is_true(autocmd_spy.was_called())
    end)
  end)

  describe("command implementations", function()
    before_each(function()
      init_module.setup({})
    end)
    
    describe("write_function", function()
      it("should show input dialog when no description provided", function()
        local input_spy = helpers.create_spy()
        mock_ui.input_dialog = input_spy.fn
        
        init_module.write_function({})
        
        assert.is_true(input_spy.was_called())
      end)
      
      it("should generate code when description provided", function()
        local api_spy = helpers.create_spy()
        mock_api.generate_code = api_spy.fn
        
        init_module.write_function({ args = "create a hello world function" })
        
        assert.is_true(api_spy.was_called_with("create a hello world function"))
      end)
    end)
    
    describe("implement_todo", function()
      it("should find TODO in current line", function()
        vim.api.nvim_get_current_line = function() return "-- TODO: implement this function" end
        
        local api_spy = helpers.create_spy()
        mock_api.generate_code = api_spy.fn
        
        init_module.implement_todo()
        
        assert.is_true(api_spy.was_called_with("implement this function"))
      end)
      
      it("should show error when no TODO found", function()
        vim.api.nvim_get_current_line = function() return "regular code line" end
        vim.api.nvim_buf_get_lines = function() return {"regular code line"} end
        
        local error_spy = helpers.create_spy()
        mock_ui.show_error = error_spy.fn
        
        init_module.implement_todo()
        
        assert.is_true(error_spy.was_called_with("No TODO comment found near cursor"))
      end)
    end)
    
    describe("explain_code", function()
      it("should explain selected code", function()
        local context = helpers.create_test_context()
        context.selection = "function test() return true end"
        mock_ui.get_current_context = function() return context end
        
        local api_spy = helpers.create_spy()
        mock_api.explain_code = api_spy.fn
        
        init_module.explain_code({})
        
        assert.is_true(api_spy.was_called())
      end)
      
      it("should show error when no code selected", function()
        local context = helpers.create_test_context()
        context.selection = nil
        context.file_content = ""
        mock_ui.get_current_context = function() return context end
        
        local error_spy = helpers.create_spy()
        mock_ui.show_error = error_spy.fn
        
        init_module.explain_code({})
        
        assert.is_true(error_spy.was_called_with("No code selected or file is empty"))
      end)
    end)
    
    describe("debug_error", function()
      it("should analyze error from arguments", function()
        local api_spy = helpers.create_spy()
        mock_api.analyze_error = api_spy.fn
        
        init_module.debug_error({ args = "TypeError: undefined is not a function" })
        
        assert.is_true(api_spy.was_called_with("TypeError: undefined is not a function"))
      end)
      
      it("should get error from quickfix list when no args", function()
        vim.fn.getqflist = function() 
          return {{ text = "Error from quickfix" }}
        end
        
        local api_spy = helpers.create_spy()
        mock_api.analyze_error = api_spy.fn
        
        init_module.debug_error({})
        
        assert.is_true(api_spy.was_called_with("Error from quickfix"))
      end)
      
      it("should show input dialog when no error found", function()
        vim.fn.getqflist = function() return {} end
        
        local input_spy = helpers.create_spy()
        mock_ui.input_dialog = input_spy.fn
        
        init_module.debug_error({})
        
        assert.is_true(input_spy.was_called())
      end)
    end)
    
    describe("generate_tests", function()
      it("should generate tests for selected code", function()
        local context = helpers.create_test_context()
        context.selection = "function add(a, b) return a + b end"
        mock_ui.get_current_context = function() return context end
        
        local api_spy = helpers.create_spy()
        mock_api.generate_tests = api_spy.fn
        
        init_module.generate_tests({})
        
        assert.is_true(api_spy.was_called())
      end)
      
      it("should show error when no code selected", function()
        local context = helpers.create_test_context()
        context.selection = nil
        mock_ui.get_current_context = function() return context end
        
        local error_spy = helpers.create_spy()
        mock_ui.show_error = error_spy.fn
        
        init_module.generate_tests({})
        
        assert.is_true(error_spy.was_called_with("Please select code to generate tests for"))
      end)
    end)
  end)

  describe("helper functions", function()
    before_each(function()
      init_module.setup({})
    end)
    
    describe("_generate_code", function()
      it("should call API and show response", function()
        local api_spy = helpers.create_spy()
        mock_api.generate_code = api_spy.fn
        
        local ui_spy = helpers.create_spy()
        mock_ui.show_response = ui_spy.fn
        
        init_module._generate_code("test description", "function")
        
        assert.is_true(api_spy.was_called_with("test description"))
      end)
    end)
    
    describe("_analyze_error", function()
      it("should call API and show response", function()
        local api_spy = helpers.create_spy()
        mock_api.analyze_error = api_spy.fn
        
        init_module._analyze_error("test error")
        
        assert.is_true(api_spy.was_called_with("test error"))
      end)
    end)
  end)

  describe("advanced features", function()
    before_each(function()
      init_module.setup({})
    end)
    
    describe("analyze_stack_trace", function()
      it("should analyze stack trace from clipboard", function()
        vim.fn.getreg = function() return "Error: test\\n  at line 1" end
        
        local spy = helpers.create_spy()
        init_module._analyze_stack_trace = spy.fn
        
        init_module.analyze_stack_trace()
        
        assert.is_true(spy.was_called())
      end)
      
      it("should get stack trace from quickfix when clipboard empty", function()
        vim.fn.getreg = function() return "" end
        vim.fn.getqflist = function() 
          return {{ text = "Error from qf" }}
        end
        
        local spy = helpers.create_spy()
        init_module._analyze_stack_trace = spy.fn
        
        init_module.analyze_stack_trace()
        
        assert.is_true(spy.was_called())
      end)
    end)
    
    describe("refactor_extract", function()
      it("should show selection dialog", function()
        local context = helpers.create_test_context()
        context.selection = "some code to extract"
        mock_ui.get_current_context = function() return context end
        
        local select_spy = helpers.create_spy()
        mock_ui.select_dialog = select_spy.fn
        
        init_module.refactor_extract({})
        
        assert.is_true(select_spy.was_called())
        
        -- Check dialog options
        local call = select_spy.calls[1]
        local options = call[1]
        assert.is_true(vim.tbl_contains(options, "Extract Method"))
        assert.is_true(vim.tbl_contains(options, "Extract Class"))
      end)
    end)
    
    describe("refactor_rename", function()
      it("should analyze current word under cursor", function()
        vim.fn.expand = function(arg)
          if arg == "<cword>" then return "variableName" end
          return ""
        end
        
        local api_spy = helpers.create_spy()
        mock_api.request = api_spy.fn
        
        init_module.refactor_rename()
        
        assert.is_true(api_spy.was_called())
        -- Check that the prompt contains the variable name
        local call = api_spy.calls[1]
        local prompt = call[1]
        assert.is_true(string.find(prompt, "variableName") ~= nil)
      end)
    end)
  end)

  describe("status and utility", function()
    before_each(function()
      init_module.setup({})
    end)
    
    describe("show_status", function()
      it("should display plugin status", function()
        local ui_spy = helpers.create_spy()
        mock_ui.show_response = ui_spy.fn
        
        init_module.show_status()
        
        assert.is_true(ui_spy.was_called())
        
        -- Check status content
        local call = ui_spy.calls[1]
        local status_content = call[1]
        assert.is_true(type(status_content) == "table")
        assert.is_true(#status_content > 0)
      end)
    end)
    
    describe("show_help", function()
      it("should display help content", function()
        local ui_spy = helpers.create_spy()
        mock_ui.show_response = ui_spy.fn
        
        init_module.show_help()
        
        assert.is_true(ui_spy.was_called())
        
        -- Check that help content is shown
        local call = ui_spy.calls[1]
        local help_content = call[1]
        assert.is_string(help_content)
        assert.is_true(string.find(help_content, "Claude Code") ~= nil)
      end)
    end)
    
    describe("toggle_completion", function()
      it("should toggle completion feature", function()
        local update_spy = helpers.create_spy()
        mock_config.update = update_spy.fn
        
        local success_spy = helpers.create_spy()
        mock_ui.show_success = success_spy.fn
        
        init_module.toggle_completion()
        
        assert.is_true(update_spy.was_called())
        assert.is_true(success_spy.was_called())
      end)
    end)
  end)
end)