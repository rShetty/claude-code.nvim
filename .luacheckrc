-- Luacheck configuration for Claude Code Neovim Plugin

-- Global options
std = "max"
cache = true
codes = true

-- File patterns to exclude
exclude_files = {
  "tests/fixtures/**/*.lua",
  ".luarocks/**/*",
}

-- Global variables allowed
globals = {
  "vim",
}

-- Read-only global variables
read_globals = {
  "vim",
  -- Busted test framework
  "describe", "it", "before_each", "after_each", "setup", "teardown",
  "assert", "spy", "stub", "mock", "finally", "pending",
  -- Common Lua globals we might use
  "unpack",
}

-- Files with different rules
files["tests/**/*_spec.lua"] = {
  read_globals = {
    "describe", "it", "before_each", "after_each", "setup", "teardown",
    "assert", "spy", "stub", "mock", "finally", "pending",
    "vim", 
  }
}

files["lua/**/*.lua"] = {
  max_line_length = 100,
}

-- Warnings to ignore
ignore = {
  "212", -- Unused argument
  "213", -- Unused loop variable  
  "631", -- Line is too long
}

-- Warnings to enable
enable = {
  "111", -- Setting non-standard global variable
  "112", -- Mutating non-standard global variable
  "113", -- Accessing undefined variable
}

-- Maximum complexity
max_cyclomatic_complexity = 10

-- Check for unused variables
unused = true
unused_args = false
unused_secondaries = false