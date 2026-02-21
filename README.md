# Claude Code for Neovim 🚀

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![CI](https://github.com/username/claude-code.nvim/workflows/CI/badge.svg)](https://github.com/username/claude-code.nvim/actions)
[![codecov](https://codecov.io/gh/username/claude-code.nvim/branch/main/graph/badge.svg)](https://codecov.io/gh/username/claude-code.nvim)
[![LuaRocks](https://img.shields.io/luarocks/v/username/claude-code.nvim?color=blue)](https://luarocks.org/modules/username/claude-code.nvim)

A **comprehensive Neovim plugin** that transforms your coding experience with Claude AI's advanced capabilities. Get intelligent code suggestions, automated debugging, security analysis, test generation, and sophisticated refactoring—all seamlessly integrated into your Neovim workflow.

**🎯 Competitive with Cursor AI** - Featuring agentic workflows, multi-file editing, background processing, and advanced context understanding.

![Demo](https://github.com/username/claude-code.nvim/raw/main/assets/demo.gif)

## ✨ Features

### 🔧 **Code Writing & Generation**
- **🎯 Smart Code Completion** - Context-aware completions with deep codebase understanding
- **⚡ Function Generation** - Create complete functions from natural language descriptions
- **📝 TODO Implementation** - Automatically implement TODO comments with proper code
- **💡 Code Explanation** - Get detailed explanations of complex code structures
- **🧬 Multi-file Context** - Generate code that understands your entire project structure

### 🐛 **Advanced Debugging & Analysis** 
- **🔍 Error Analysis** - Deep error message analysis with intelligent explanations
- **🎯 Fix Suggestions** - Get specific, actionable solutions for code issues
- **📊 Stack Trace Analysis** - Comprehensive stack trace interpretation with root cause detection
- **🔧 Performance Debugging** - Identify bottlenecks and optimization opportunities
- **⚠️ Security Vulnerability Scanning** - OWASP Top 10 and security best practice checks

### 📋 **Intelligent Code Review**
- **🛡️ Security Analysis** - Identify vulnerabilities with severity levels and fixes
- **⚡ Performance Review** - Algorithm complexity and optimization suggestions
- **🏗️ Architecture Analysis** - Design patterns and structural improvements
- **📏 Code Quality** - Maintainability, readability, and best practice compliance
- **🔄 Dependency Analysis** - Import/export relationship understanding

### 🧪 **Smart Testing & Quality**
- **🎯 Test Generation** - Comprehensive unit tests with edge cases and assertions
- **🎭 Mock Objects** - Generate appropriate mocks with configurable behaviors
- **📊 Coverage Analysis** - Identify untested code paths and suggest test cases
- **🔗 Integration Tests** - Support for end-to-end test scaffolding
- **🚀 Performance Tests** - Generate benchmarking and load test scenarios

### ♻️ **Advanced Refactoring**
- **🔄 Extract Methods/Classes** - Smart extraction with meaningful naming
- **⚡ Algorithm Optimization** - Performance improvements and complexity reduction
- **📝 Intelligent Renaming** - Context-aware variable and function renaming
- **🏗️ Architecture Refactoring** - Dependency injection and design pattern application
- **🎨 Code Style Improvements** - Language-specific conventions and formatting

### 🤖 **Agentic Workflows (Cursor-like)**
- **👥 Multi-Agent Support** - Run multiple AI tasks concurrently
- **📋 Plan Mode** - Generate and execute structured development plans
- **⏰ Background Agents** - Long-running tasks with progress tracking
- **🔄 Task Queue Management** - Prioritize and manage AI operations
- **🧠 Agent Communication** - Context sharing between different AI agents

---

## 🚀 Quick Start

1. **Install** the plugin using your favorite package manager
2. **Set your API key**: `export ANTHROPIC_API_KEY="your-key"`
3. **Configure** the plugin: `require('claudeai').setup({})`
4. **Start coding** with AI assistance!

```lua
-- Minimal setup
require('claudeai').setup({
  api = { key = vim.env.ANTHROPIC_API_KEY }
})
```

## 📦 Installation

### Prerequisites

- **Neovim 0.8.0+** (0.9.0+ recommended)
- **Anthropic API key** or **Claude CLI** installed
- **curl** for API requests
- **Git** for installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim) ⭐ **Recommended**

```lua
{
  'username/claude-code.nvim',
  event = "VeryLazy", -- Load on demand for better startup time
  dependencies = {
    "nvim-lua/plenary.nvim", -- Required for async operations
  },
  config = function()
    require('claudeai').setup({
      api = {
        key = vim.env.ANTHROPIC_API_KEY, -- Secure: use environment variable
        model = "claude-3-5-sonnet-20241022", -- Latest model
      },
      features = {
        completion = { enabled = true },
        code_review = { enabled = true },
        debugging = { enabled = true },
      }
    })
  end,
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  'claudeai.nvim',
  config = function()
    require('claudeai').setup({
      api = {
        key = vim.env.ANTHROPIC_API_KEY,
      }
    })
  end
}
```

### Using [vim-plug](https://github.com/junegunn/vim-plug)

```vim
Plug 'claudeai.nvim'
```

Then in your `init.lua`:

```lua
require('claudeai').setup({
  api = {
    key = vim.env.ANTHROPIC_API_KEY,
  }
})
```

## 🔧 Configuration

### API Setup

First, set your Anthropic API key:

```bash
export ANTHROPIC_API_KEY="your-api-key-here"
```

Or configure it directly:

```lua
require('claudeai').setup({
  api = {
    key = "your-api-key-here",
    model = "claude-3-5-sonnet-20241022", -- Latest Claude 3.5 Sonnet
    max_tokens = 4096,
    temperature = 0.1, -- Lower for more deterministic code
  }
})
```

### Feature Configuration

```lua
require('claudeai').setup({
  features = {
    completion = {
      enabled = true,
      trigger_length = 2,
      max_context_lines = 100,
      debounce_ms = 500,
    },
    code_writing = {
      enabled = true,
      include_type_hints = true,
      include_docstrings = true,
      include_error_handling = true,
    },
    debugging = {
      enabled = true,
      explain_errors = true,
      suggest_fixes = true,
      analyze_stack_trace = true,
    },
    code_review = {
      enabled = true,
      check_security = true,
      check_performance = true,
      check_maintainability = true,
      max_file_size = 10000, -- lines
    },
    testing = {
      enabled = true,
      generate_edge_cases = true,
      include_mocks = true,
    },
    refactoring = {
      enabled = true,
      extract_methods = true,
      optimize_algorithms = true,
      improve_naming = true,
    },
  }
})
```

### UI Customization

```lua
require('claudeai').setup({
  ui = {
    float_border = "rounded", -- "none", "single", "double", "rounded", "solid", "shadow"
    float_width = 0.8,
    float_height = 0.6,
    progress_indicator = true,
    syntax_highlighting = true,
  }
})
```

### Custom Keybindings

```lua
require('claudeai').setup({
  keymaps = {
    commands = {
      -- Code writing
      write_function = "<leader>cf",
      implement_todo = "<leader>ci",
      explain_code = "<leader>ce",
      
      -- Debugging
      debug_error = "<leader>cd",
      analyze_stack = "<leader>cs",
      suggest_fix = "<leader>cx",
      
      -- Code review
      review_code = "<leader>cr",
      review_file = "<leader>cR",
      security_check = "<leader>cS",
      
      -- Testing
      generate_tests = "<leader>ct",
      generate_mocks = "<leader>cm",
      
      -- Refactoring
      refactor_extract = "<leader>re",
      refactor_optimize = "<leader>ro",
      
      -- General
      claude_chat = "<leader>cc",
      claude_help = "<leader>ch",
    },
  }
})
```

## 🚀 Usage

### Code Writing Commands

| Command | Description | Keybinding |
|---------|-------------|------------|
| `:ClaudeWriteFunction` | Generate function from description | `<leader>cw` |
| `:ClaudeImplementTodo` | Implement TODO comment | `<leader>ci` |
| `:ClaudeExplainCode` | Explain selected code | `<leader>ce` |

### Debugging Commands

| Command | Description | Keybinding |
|---------|-------------|------------|
| `:ClaudeDebugError` | Debug error message | `<leader>cd` |
| `:ClaudeAnalyzeStack` | Analyze stack trace | `<leader>cs` |
| `:ClaudeSuggestFix` | Suggest fix for code issue | `<leader>cf` |

### Code Review Commands

| Command | Description | Keybinding |
|---------|-------------|------------|
| `:ClaudeReviewCode` | Review selected code | `<leader>cr` |
| `:ClaudeReviewFile` | Review entire file | `<leader>cR` |
| `:ClaudeSecurityCheck` | Security vulnerability check | `<leader>cS` |

### Testing Commands

| Command | Description | Keybinding |
|---------|-------------|------------|
| `:ClaudeGenerateTests` | Generate tests for selected code | `<leader>ct` |
| `:ClaudeGenerateMocks` | Generate mock objects | `<leader>cm` |
| `:ClaudeTestCoverage` | Test coverage analysis | `<leader>cC` |

### Refactoring Commands

| Command | Description | Keybinding |
|---------|-------------|------------|
| `:ClaudeRefactorExtract` | Extract method/class | `<leader>re` |
| `:ClaudeRefactorOptimize` | Optimize code | `<leader>ro` |
| `:ClaudeRefactorRename` | Intelligent rename suggestions | `<leader>rn` |

### General Commands

| Command | Description | Keybinding |
|---------|-------------|------------|
| `:ClaudeChat` | Open Claude Code chat | `<leader>cc` |
| `:ClaudeHelp` | Show help | `<leader>ch` |
| `:ClaudeStatus` | Show plugin status | - |
| `:ClaudeToggleCompletion` | Toggle code completion | - |

## 📝 Examples

### Generate a Function

1. Use `:ClaudeWriteFunction` or `<leader>cw`
2. Describe what you want: "Create a binary search function that takes a sorted array and target value"
3. Claude Code will generate a complete, well-documented function with error handling

### Implement TODO

1. Place cursor on or near a TODO comment:
   ```python
   # TODO: Add input validation for email addresses
   ```
2. Use `:ClaudeImplementTodo` or `<leader>ci`
3. Claude Code will implement the validation logic

### Code Review

1. Select code or use entire file
2. Use `:ClaudeReviewCode` or `<leader>cr`
3. Get comprehensive feedback on security, performance, and maintainability

### Debug Error

1. Use `:ClaudeDebugError` or `<leader>cd`
2. Paste your error message
3. Get detailed analysis and specific solutions

### Generate Tests

1. Select a function or method
2. Use `:ClaudeGenerateTests` or `<leader>ct`
3. Get comprehensive tests including edge cases

## 🎨 UI Features

### Floating Windows
- Beautiful floating windows with rounded borders
- Syntax highlighting for code responses
- Easy navigation with `q` to close, `y` to copy content

### Loading Indicators
- Animated loading spinners during AI processing
- Progress indicators for long-running operations
- Cancellable requests with `<Esc>`

### Code Application
- Direct code application with `<CR>` or `a` key
- Smart code insertion at cursor position
- Undo-friendly operations

## 🔧 Troubleshooting

### API Key Issues
```bash
# Check if API key is set
echo $ANTHROPIC_API_KEY

# Set API key temporarily
export ANTHROPIC_API_KEY="your-key-here"

# Check plugin status
:ClaudeStatus
```

### Performance Issues
- Reduce `max_context_lines` in completion settings
- Increase `debounce_ms` for completion
- Disable features you don't use

### Error Messages
- Check `:ClaudeStatus` for configuration issues
- Ensure you have `curl` installed
- Verify internet connectivity

## 🚀 Performance & Best Practices

### Optimization Tips

- **Context Management**: Use smaller `max_context_lines` for faster responses
- **Feature Toggling**: Disable unused features to reduce memory usage
- **Request Batching**: Group related operations together
- **Caching**: Responses are cached automatically for repeated queries

### Security Best Practices

```bash
# Store API key securely
echo 'export ANTHROPIC_API_KEY="sk-..."' >> ~/.zshrc

# Or use a secrets manager
echo 'export ANTHROPIC_API_KEY=$(pass anthropic/api-key)' >> ~/.zshrc
```

## 🆚 Comparison with Cursor AI

| Feature | Claude Code Neovim | Cursor AI |
|---------|-------------------|----------|
| **Multi-Agent Workflows** | ✅ Concurrent agents | ✅ Up to 8 agents |
| **Plan Mode** | ✅ Structured dev plans | ✅ Editable plans |
| **Background Processing** | ✅ Long-running tasks | ✅ Isolated environments |
| **Context Understanding** | ✅ Deep codebase analysis | ✅ Project-wide context |
| **Security Analysis** | ✅ OWASP Top 10 + custom | ✅ General security |
| **Test Generation** | ✅ Edge cases + mocks | ✅ Basic test generation |
| **Refactoring** | ✅ Advanced patterns | ✅ Basic refactoring |
| **Cost** | 🆓 **Open Source** | 💰 Paid tiers |
| **Customization** | ✅ **Highly configurable** | ⚠️ Limited customization |
| **Vim Integration** | ✅ **Native Neovim** | ❌ VS Code fork only |

## 🧪 Testing & Development

### Running Tests

```bash
# Install dependencies
make install

# Run tests
make test

# Run with coverage
make test-coverage

# Lint code
make lint

# Format code
make format
```

### Development Setup

```bash
# Clone the repository
git clone https://github.com/username/claude-code.nvim.git
cd claude-code.nvim

# Install development dependencies
make install

# Run tests in watch mode
make test-watch
```

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

### Quick Contributing Steps

1. **Fork** the repository
2. **Create** a feature branch: `git checkout -b amazing-feature`
3. **Commit** your changes: `git commit -m 'Add amazing feature'`
4. **Push** to the branch: `git push origin amazing-feature`
5. **Open** a Pull Request

### Areas We Need Help With

- 🐛 **Bug fixes** and stability improvements
- 📚 **Documentation** and tutorials
- 🧪 **Test coverage** expansion
- 🌐 **Internationalization** support
- ⚡ **Performance** optimizations
- 🎨 **UI/UX** improvements

## 📊 Roadmap

- **Q1 2026**: Multi-modal support (images, voice)
- **Q2 2026**: Local model support (Ollama integration)
- **Q3 2026**: Team collaboration features
- **Q4 2026**: Plugin ecosystem and extensions

## 🆘 Support & Community

- 📖 **Documentation**: [Full docs](https://github.com/username/claude-code.nvim/wiki)
- 🐛 **Issues**: [GitHub Issues](https://github.com/username/claude-code.nvim/issues)
- 💬 **Discussions**: [GitHub Discussions](https://github.com/username/claude-code.nvim/discussions)
- 💌 **Email**: maintainers@example.com

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **Anthropic** for the amazing Claude AI
- **Neovim** community for the excellent plugin ecosystem
- **Cursor AI** for inspiration on agentic workflows
- All **contributors** who make this project better

---

<p align="center">
  <strong>⭐ Star us on GitHub if this plugin helps you code better! ⭐</strong>
</p>

<p align="center">
  Made with ❤️ by the Claude Code Neovim community
</p>
