-- Utility functions for Claude Code Neovim plugin
local M = {}

-- String utilities
M.string = {}

-- Trim whitespace from both ends of a string
function M.string.trim(str)
  if not str then
    return ""
  end
  return str:match("^%s*(.-)%s*$") or ""
end

-- Split string by delimiter
function M.string.split(str, delimiter)
  if not str then
    return {}
  end
  
  local result = {}
  local pattern = "([^" .. delimiter .. "]+)"
  
  for match in str:gmatch(pattern) do
    table.insert(result, match)
  end
  
  return result
end

-- Check if string is empty or only whitespace
function M.string.is_empty(str)
  return not str or M.string.trim(str) == ""
end

-- Escape special regex characters
function M.string.escape_pattern(str)
  if not str then
    return ""
  end
  return str:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
end

-- Table utilities
M.table = {}

-- Deep copy a table
function M.table.deep_copy(original)
  if type(original) ~= 'table' then
    return original
  end
  
  local copy = {}
  for k, v in pairs(original) do
    copy[k] = M.table.deep_copy(v)
  end
  
  return copy
end

-- Check if table is empty
function M.table.is_empty(tbl)
  return not tbl or next(tbl) == nil
end

-- Merge tables (deep merge)
function M.table.deep_merge(target, source)
  if type(target) ~= 'table' then
    target = {}
  end
  
  if type(source) ~= 'table' then
    return target
  end
  
  for k, v in pairs(source) do
    if type(v) == 'table' and type(target[k]) == 'table' then
      target[k] = M.table.deep_merge(target[k], v)
    else
      target[k] = v
    end
  end
  
  return target
end

-- File utilities
M.file = {}

-- Get file extension
function M.file.get_extension(filename)
  if not filename then
    return ""
  end
  return filename:match("^.+%.(.+)$") or ""
end

-- Get filename without extension
function M.file.get_basename(filename)
  if not filename then
    return ""
  end
  local base = filename:match("([^/\\]+)$") or filename
  return base:match("^(.+)%..+$") or base
end

-- Validation utilities
M.validate = {}

-- Check if value is a non-empty string
function M.validate.non_empty_string(value)
  return type(value) == "string" and not M.string.is_empty(value)
end

-- Check if value is a valid function
function M.validate.is_function(value)
  return type(value) == "function"
end

-- Check if value is a valid table
function M.validate.is_table(value)
  return type(value) == "table"
end

-- Extend string metatable to add trim method for convenience
-- This allows using str:trim() syntax
local string_mt = getmetatable("")
if string_mt then
  string_mt.__index.trim = M.string.trim
  string_mt.__index.split = M.string.split
  string_mt.__index.is_empty = M.string.is_empty
  string_mt.__index.escape_pattern = M.string.escape_pattern
end

return M