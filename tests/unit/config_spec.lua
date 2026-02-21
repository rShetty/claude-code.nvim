-- Unit tests for claudeai.config module
local helpers = require('tests.helpers')

describe("claudeai.config", function()
  local config
  
  before_each(function()
    helpers.setup_vim_mock()
    -- Reset package cache to get fresh module
    package.loaded['claudeai.config'] = nil
    config = require('claudeai.config')
  end)
  
  after_each(function()
    package.loaded['claudeai.config'] = nil
  end)

  describe("defaults", function()
    it("should have correct default API configuration", function()
      local defaults = config.defaults
      
      assert.is_not_nil(defaults.api)
      assert.equals("https://api.anthropic.com/v1", defaults.api.base_url)
      assert.equals("claude-3-5-sonnet-20241022", defaults.api.model)
      assert.equals(4096, defaults.api.max_tokens)
      assert.equals(0.1, defaults.api.temperature)
      assert.equals(30000, defaults.api.timeout)
    end)
    
    it("should have all required feature flags", function()
      local defaults = config.defaults
      
      assert.is_not_nil(defaults.features)
      assert.is_true(defaults.features.completion.enabled)
      assert.is_true(defaults.features.code_writing.enabled)
      assert.is_true(defaults.features.debugging.enabled)
      assert.is_true(defaults.features.code_review.enabled)
      assert.is_true(defaults.features.testing.enabled)
      assert.is_true(defaults.features.refactoring.enabled)
    end)
    
    it("should have reasonable UI defaults", function()
      local defaults = config.defaults
      
      assert.is_not_nil(defaults.ui)
      assert.equals("rounded", defaults.ui.float_border)
      assert.equals(0.8, defaults.ui.float_width)
      assert.equals(0.6, defaults.ui.float_height)
      assert.is_true(defaults.ui.progress_indicator)
      assert.is_true(defaults.ui.syntax_highlighting)
    end)
    
    it("should have default keymaps", function()
      local defaults = config.defaults
      
      assert.is_not_nil(defaults.keymaps)
      assert.is_not_nil(defaults.keymaps.commands)
      assert.equals("<leader>cw", defaults.keymaps.commands.write_function)
      assert.equals("<leader>ci", defaults.keymaps.commands.implement_todo)
    end)
    
    it("should have all required prompts", function()
      local defaults = config.defaults
      
      assert.is_not_nil(defaults.prompts)
      assert.is_string(defaults.prompts.code_completion)
      assert.is_string(defaults.prompts.code_generation)
      assert.is_string(defaults.prompts.code_explanation)
      assert.is_string(defaults.prompts.debug_analysis)
      assert.is_string(defaults.prompts.code_review)
      assert.is_string(defaults.prompts.test_generation)
      assert.is_string(defaults.prompts.refactoring)
    end)
  end)

  describe("setup", function()
    it("should merge user config with defaults", function()
      local user_config = {
        api = {
          model = "claude-3-opus-20240229",
          temperature = 0.5
        },
        features = {
          completion = {
            enabled = false
          }
        }
      }
      
      config.setup(user_config)
      local final_config = config.get()
      
      assert.equals("claude-3-opus-20240229", final_config.api.model)
      assert.equals(0.5, final_config.api.temperature)
      assert.equals(4096, final_config.api.max_tokens) -- should keep default
      assert.is_false(final_config.features.completion.enabled)
      assert.is_true(final_config.features.code_writing.enabled) -- should keep default
    end)
    
    it("should handle empty user config", function()
      config.setup({})
      local final_config = config.get()
      
      -- Should be identical to defaults
      assert.equals(config.defaults.api.model, final_config.api.model)
      assert.equals(config.defaults.api.temperature, final_config.api.temperature)
    end)
    
    it("should handle nil user config", function()
      config.setup(nil)
      local final_config = config.get()
      
      -- Should be identical to defaults
      assert.equals(config.defaults.api.model, final_config.api.model)
    end)
    
    it("should read API key from environment", function()
      vim.env.ANTHROPIC_API_KEY = "env-test-key"
      
      config.setup({})
      local final_config = config.get()
      
      assert.equals("env-test-key", final_config.api.key)
    end)
    
    it("should prefer user config API key over environment", function()
      vim.env.ANTHROPIC_API_KEY = "env-key"
      
      config.setup({
        api = {
          key = "user-key"
        }
      })
      local final_config = config.get()
      
      assert.equals("user-key", final_config.api.key)
    end)
  end)

  describe("validation", function()
    it("should cap max_tokens at Claude's limit", function()
      config.setup({
        api = {
          max_tokens = 10000
        }
      })
      local final_config = config.get()
      
      assert.equals(8192, final_config.api.max_tokens)
    end)
    
    it("should cap temperature between 0 and 1", function()
      config.setup({
        api = {
          temperature = -0.5
        }
      })
      local final_config = config.get()
      assert.equals(0.0, final_config.api.temperature)
      
      config.setup({
        api = {
          temperature = 1.5
        }
      })
      final_config = config.get()
      assert.equals(1.0, final_config.api.temperature)
    end)
  end)

  describe("get", function()
    it("should return current configuration", function()
      config.setup({
        api = {
          model = "test-model"
        }
      })
      
      local current_config = config.get()
      assert.equals("test-model", current_config.api.model)
    end)
  end)

  describe("update", function()
    it("should update configuration at runtime", function()
      config.setup({})
      local initial_config = config.get()
      assert.equals("claude-3-5-sonnet-20241022", initial_config.api.model)
      
      config.update({
        api = {
          model = "updated-model"
        }
      })
      
      local updated_config = config.get()
      assert.equals("updated-model", updated_config.api.model)
    end)
    
    it("should preserve unmodified settings", function()
      config.setup({})
      
      config.update({
        api = {
          model = "new-model"
        }
      })
      
      local updated_config = config.get()
      assert.equals("new-model", updated_config.api.model)
      assert.equals(4096, updated_config.api.max_tokens) -- should preserve
    end)
  end)
end)