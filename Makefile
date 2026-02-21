.PHONY: help test lint format install clean docs coverage check

# Default target
help: ## Show this help message
	@echo 'Claude Code Neovim Plugin - Development Makefile'
	@echo ''
	@echo 'Usage:'
	@echo '  make <target>'
	@echo ''
	@echo 'Targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# Testing
test: ## Run all tests
	@echo "Running tests..."
	busted --verbose

test-coverage: ## Run tests with coverage
	@echo "Running tests with coverage..."
	busted --coverage --verbose
	luacov
	@echo "Coverage report generated: luacov.report.out"

test-watch: ## Run tests in watch mode
	@echo "Running tests in watch mode..."
	find lua/ tests/ -name "*.lua" | entr -c make test

# Linting and Formatting
lint: ## Run linting
	@echo "Running luacheck..."
	luacheck lua/ --config .luacheckrc

format: ## Format code with StyLua
	@echo "Formatting code..."
	stylua lua/ tests/ --config-path=.stylua.toml

format-check: ## Check if code is formatted
	@echo "Checking code formatting..."
	stylua --check lua/ tests/ --config-path=.stylua.toml

# Installation and Setup
install: ## Install development dependencies
	@echo "Installing dependencies..."
	@command -v luarocks >/dev/null 2>&1 || { echo "Please install LuaRocks first"; exit 1; }
	luarocks install busted
	luarocks install luacov
	luarocks install luacheck
	@command -v npm >/dev/null 2>&1 && npm install -g stylua || echo "npm not found, skipping stylua installation"

# Documentation
docs: ## Generate documentation
	@echo "Generating documentation..."
	ldoc lua/ -d doc/

docs-serve: ## Serve documentation locally
	@echo "Serving documentation on http://localhost:8080"
	@command -v python3 >/dev/null 2>&1 && cd doc && python3 -m http.server 8080 || echo "python3 not found"

# Cleanup
clean: ## Clean generated files
	@echo "Cleaning up..."
	rm -f luacov.*.out
	rm -rf doc/
	rm -rf release/
	rm -f test-results.json

# Development checks
check: lint format-check test ## Run all checks (lint, format, test)

# Plugin testing in Neovim
test-plugin: ## Test plugin in minimal Neovim config
	@echo "Testing plugin with minimal config..."
	nvim --clean -c "set rtp+=." -c "lua require('claude-code').setup({api = {key = 'test'}})" -c "ClaudeHelp"

# Release preparation
prepare-release: check docs ## Prepare for release (run all checks and generate docs)
	@echo "Release preparation complete!"

# Performance profiling
profile: ## Run performance tests
	@echo "Running performance profile..."
	busted tests/performance/ --verbose --output=json > profile-results.json

# Git hooks
install-hooks: ## Install git hooks
	@echo "Installing git hooks..."
	cp scripts/pre-commit .git/hooks/
	chmod +x .git/hooks/pre-commit

# Database of commands for easy reference
commands: ## List all available Claude Code commands
	@echo "Claude Code Commands:"
	@echo "  :ClaudeWriteFunction    - Generate function from description"
	@echo "  :ClaudeImplementTodo    - Implement TODO comment"
	@echo "  :ClaudeExplainCode      - Explain selected code"
	@echo "  :ClaudeDebugError       - Debug error message"
	@echo "  :ClaudeAnalyzeStack     - Analyze stack trace"
	@echo "  :ClaudeSuggestFix       - Suggest code fixes"
	@echo "  :ClaudeReviewCode       - Review selected code"
	@echo "  :ClaudeReviewFile       - Review entire file"
	@echo "  :ClaudeSecurityCheck    - Security vulnerability check"
	@echo "  :ClaudeGenerateTests    - Generate tests for code"
	@echo "  :ClaudeGenerateMocks    - Generate mock objects"
	@echo "  :ClaudeTestCoverage     - Test coverage analysis"
	@echo "  :ClaudeRefactorExtract  - Extract method/class"
	@echo "  :ClaudeRefactorOptimize - Optimize code performance"
	@echo "  :ClaudeRefactorRename   - Intelligent rename suggestions"
	@echo "  :ClaudeChat             - Open chat interface"
	@echo "  :ClaudeHelp             - Show help"
	@echo "  :ClaudeStatus           - Show plugin status"