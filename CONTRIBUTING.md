# Contributing to Claude Code Neovim Plugin

Thank you for your interest in contributing to the Claude Code Neovim Plugin! This document provides guidelines and information for contributors.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [How to Contribute](#how-to-contribute)
- [Pull Request Process](#pull-request-process)
- [Coding Standards](#coding-standards)
- [Testing](#testing)
- [Documentation](#documentation)

## Code of Conduct

This project adheres to a [Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code.

## Getting Started

1. **Fork the repository** on GitHub
2. **Clone your fork** locally:
   ```bash
   git clone https://github.com/your-username/claude-code.nvim.git
   cd claude-code.nvim
   ```
3. **Create a branch** for your changes:
   ```bash
   git checkout -b feature/your-feature-name
   ```

## Development Setup

### Prerequisites

- Neovim 0.8.0 or later
- Lua 5.1+ (comes with Neovim)
- [busted](https://olivinelabs.com/busted/) for testing
- An Anthropic API key or Claude CLI for testing

### Local Development

1. **Install the plugin locally**:
   ```bash
   # Using lazy.nvim
   {
     'your-username/claude-code.nvim',
     dir = '/path/to/your/local/claude-code.nvim',
     config = function()
       require('claudeai').setup({
         api = { key = 'your-api-key' }
       })
     end
   }
   ```

2. **Install testing dependencies**:
   ```bash
   luarocks install busted
   luarocks install luacov  # for coverage
   ```

3. **Run tests**:
   ```bash
   busted tests/
   ```

## How to Contribute

### Types of Contributions

We welcome various types of contributions:

- **Bug fixes** - Help us fix issues in the codebase
- **Feature additions** - Implement new functionality
- **Documentation** - Improve or add documentation
- **Testing** - Write tests or improve test coverage
- **Performance** - Optimize existing code
- **UI/UX** - Improve user experience

### Finding Issues to Work On

- Check the [Issues](https://github.com/your-repo/claude-code.nvim/issues) page
- Look for issues labeled `good first issue` for newcomers
- Issues labeled `help wanted` are ready for contribution
- Feel free to create new issues for bugs or feature requests

## Pull Request Process

1. **Ensure your code follows** our [coding standards](#coding-standards)
2. **Add or update tests** for your changes
3. **Update documentation** if needed
4. **Run tests** and ensure they pass:
   ```bash
   make test
   ```
5. **Lint your code**:
   ```bash
   make lint
   ```
6. **Update CHANGELOG.md** with your changes
7. **Submit a pull request** with:
   - Clear title and description
   - Reference any related issues
   - Screenshots/GIFs for UI changes

### Pull Request Template

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Testing
- [ ] Tests pass locally
- [ ] New tests added for new functionality
- [ ] Manual testing performed

## Checklist
- [ ] Code follows style guidelines
- [ ] Self-review completed
- [ ] Documentation updated
- [ ] CHANGELOG.md updated
```

## Coding Standards

### Lua Style Guide

- **Indentation**: 2 spaces, no tabs
- **Line length**: Maximum 100 characters
- **Naming**: 
  - Variables and functions: `snake_case`
  - Constants: `UPPER_SNAKE_CASE`
  - Modules: `snake_case`
- **Comments**: Use `--` for single line, `--[[]]` for multi-line

### Code Organization

```lua
-- File structure
local config = require("claudeai.config")
local api = require("claudeai.api")

local M = {}

-- Private functions (use underscore prefix)
local function _private_helper()
  -- implementation
end

-- Public functions
function M.public_function()
  -- implementation
end

return M
```

### Error Handling

- Always handle errors gracefully
- Provide meaningful error messages
- Use `pcall` for functions that might fail
- Log errors appropriately

```lua
local success, result = pcall(risky_function, param)
if not success then
  vim.notify("Error: " .. result, vim.log.levels.ERROR)
  return
end
```

## Testing

### Test Structure

```bash
tests/
├── unit/           # Unit tests for individual modules
├── integration/    # Integration tests
├── fixtures/       # Test data and fixtures
└── helpers/        # Test helper functions
```

### Writing Tests

```lua
describe("claudeai.config", function()
  it("should load default configuration", function()
    local config = require("claudeai.config")
    local defaults = config.get()
    
    assert.is_not_nil(defaults.api)
    assert.equals("claude-3-5-sonnet-20241022", defaults.api.model)
  end)
end)
```

### Running Tests

```bash
# Run all tests
busted tests/

# Run specific test file
busted tests/unit/config_spec.lua

# Run with coverage
busted --coverage tests/
```

## Documentation

### Code Documentation

- **All public functions** must have LuaLS annotations:
  ```lua
  ---Generate code based on description
  ---@param description string The code description
  ---@param context table Current buffer context
  ---@param callback function Callback with response
  function M.generate_code(description, context, callback)
  ```

- **Complex algorithms** should have inline comments
- **Configuration options** must be documented in README

### README Updates

When adding features:
1. Update the feature list
2. Add usage examples
3. Update configuration options
4. Add troubleshooting if needed

## Release Process

Releases are handled by maintainers:

1. **Version bump** in appropriate files
2. **Update CHANGELOG.md** with release notes
3. **Create GitHub release** with tag
4. **Update documentation** if needed

## Community

- Join our [discussions](https://github.com/your-repo/claude-code.nvim/discussions)
- Ask questions in [issues](https://github.com/your-repo/claude-code.nvim/issues)
- Follow the project for updates

## Recognition

Contributors are recognized in:
- GitHub contributors page
- CHANGELOG.md for significant contributions
- README.md for major features

---

Thank you for contributing to Claude Code Neovim Plugin! 🚀