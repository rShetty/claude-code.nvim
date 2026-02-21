-- Comprehensive test helpers for claude-code plugin
-- Provides mocks, utilities, performance testing, and integration test support

local M = {}

-- Test state management
local test_state = {
  original_vim = {},
  mock_timers = {},
  mock_jobs = {},
  mock_watchers = {},
  performance_data = {},
  async_operations = {},
}

-- Enhanced API Mock Creation Functions
-- ====================================

-- Create comprehensive vim.api mock
function M.create_api_mock()
  local buffers = {}
  local windows = {}
  local autocommands = {}
  local user_commands = {}
  local current_buf = 1
  local current_win = 1000
  
  return {
    -- Buffer management
    nvim_create_buf = function(listed, scratch)
      current_buf = current_buf + 1
      buffers[current_buf] = {
        lines = {},
        name = "",
        options = { filetype = "" },
        valid = true
      }
      return current_buf
    end,
    
    nvim_get_current_buf = function()
      return current_buf
    end,
    
    nvim_buf_is_valid = function(buf)
      return buffers[buf] and buffers[buf].valid or false
    end,
    
    nvim_buf_get_name = function(buf)
      return buffers[buf] and buffers[buf].name or "test.lua"
    end,
    
    nvim_buf_set_name = function(buf, name)
      if buffers[buf] then
        buffers[buf].name = name
      end
    end,
    
    nvim_buf_get_lines = function(buf, start, end_, strict)
      local lines = buffers[buf] and buffers[buf].lines or {"test line"}
      start = start or 0
      end_ = end_ == -1 and #lines or (end_ or #lines)
      
      local result = {}
      for i = start + 1, end_ do
        table.insert(result, lines[i] or "")
      end
      return result
    end,
    
    nvim_buf_set_lines = function(buf, start, end_, strict, replacement)
      if not buffers[buf] then
        buffers[buf] = { lines = {}, name = "", options = {} }
      end
      
      local lines = buffers[buf].lines
      start = start or 0
      end_ = end_ == -1 and #lines or (end_ or #lines)
      
      -- Replace lines
      for i = end_, start + 1, -1 do
        table.remove(lines, i)
      end
      
      for i, line in ipairs(replacement or {}) do
        table.insert(lines, start + i, line)
      end
    end,
    
    nvim_buf_line_count = function(buf)
      return buffers[buf] and #buffers[buf].lines or 1
    end,
    
    nvim_buf_get_option = function(buf, option)
      if buffers[buf] and buffers[buf].options[option] then
        return buffers[buf].options[option]
      end
      -- Default values for common options
      if option == "filetype" then return "lua" end
      if option == "modified" then return false end
      if option == "readonly" then return false end
      if option == "modifiable" then return true end
      return nil
    end,
    
    nvim_buf_set_option = function(buf, option, value)
      if not buffers[buf] then
        buffers[buf] = { lines = {}, name = "", options = {} }
      end
      buffers[buf].options[option] = value
    end,
    
    nvim_buf_add_highlight = function(buf, ns_id, hl_group, line, col_start, col_end)
      -- Mock highlight addition
    end,
    
    nvim_buf_call = function(buf, fn)
      return fn()
    end,
    
    -- Window management
    nvim_open_win = function(buf, enter, config)
      current_win = current_win + 1
      windows[current_win] = {
        buf = buf,
        config = config,
        valid = true,
        cursor = {1, 0}
      }
      return current_win
    end,
    
    nvim_get_current_win = function()
      return current_win
    end,
    
    nvim_win_is_valid = function(win)
      return windows[win] and windows[win].valid or false
    end,
    
    nvim_win_close = function(win, force)
      if windows[win] then
        windows[win].valid = false
      end
    end,
    
    nvim_win_get_buf = function(win)
      return windows[win] and windows[win].buf or current_buf
    end,
    
    nvim_win_set_buf = function(win, buf)
      if windows[win] then
        windows[win].buf = buf
      end
    end,
    
    nvim_win_get_cursor = function(win)
      return windows[win] and windows[win].cursor or {1, 0}
    end,
    
    nvim_win_set_cursor = function(win, pos)
      if windows[win] then
        windows[win].cursor = pos
      end
    end,
    
    nvim_win_get_option = function(win, option)
      return nil -- Default mock behavior
    end,
    
    nvim_win_set_option = function(win, option, value)
      -- Mock option setting
    end,
    
    nvim_list_wins = function()
      local win_list = {}
      for win_id, win_info in pairs(windows) do
        if win_info.valid then
          table.insert(win_list, win_id)
        end
      end
      return win_list
    end,
    
    nvim_list_bufs = function()
      local buf_list = {}
      for buf_id, buf_info in pairs(buffers) do
        if buf_info.valid then
          table.insert(buf_list, buf_id)
        end
      end
      return buf_list
    end,
    
    -- Autocommands
    nvim_create_augroup = function(name, opts)
      return { name = name, id = math.random(1000, 9999) }
    end,
    
    nvim_create_autocmd = function(event, opts)
      local autocmd_id = math.random(10000, 99999)
      autocommands[autocmd_id] = {
        event = event,
        opts = opts,
      }
      return autocmd_id
    end,
    
    -- User commands
    nvim_create_user_command = function(name, command, opts)
      user_commands[name] = {
        command = command,
        opts = opts or {}
      }
    end,
    
    -- Miscellaneous
    nvim_get_current_line = function()
      local buf_lines = buffers[current_buf] and buffers[current_buf].lines or {"test line"}
      local cursor = windows[current_win] and windows[current_win].cursor or {1, 0}
      return buf_lines[cursor[1]] or ""
    end,
    
    nvim_replace_termcodes = function(str, from_part, do_lt, special)
      return str -- Mock implementation
    end,
    
    nvim_feedkeys = function(keys, mode, escape_csi)
      -- Mock key feeding
    end,
    
    -- Mock access to internal state for testing
    _mock_state = {
      buffers = buffers,
      windows = windows,
      autocommands = autocommands,
      user_commands = user_commands,
    }
  }
end

-- Create comprehensive vim.fn mock
function M.create_fn_mock()
  return {
    expand = function(expr)
      if expr == "%:p" then return "/path/to/current/file.lua" end
      if expr == "%:p:h" then return "/path/to/current" end
      if expr == "%:t" then return "file.lua" end
      if expr == "<cword>" then return "test_word" end
      if expr == "<cfile>" then return "test_file" end
      return "expanded_" .. tostring(expr)
    end,
    
    input = function(prompt, default)
      return default or "test_input"
    end,
    
    confirm = function(msg, choices, default)
      return default or 1
    end,
    
    getcwd = function()
      return "/test/working/directory"
    end,
    
    fnamemodify = function(fname, mods)
      if mods == ":t" then return "filename.lua" end
      if mods == ":h" then return "/path/to" end
      if mods == ":e" then return "lua" end
      return fname
    end,
    
    isdirectory = function(path)
      return path:match("directory") and 1 or 0
    end,
    
    filereadable = function(path)
      return path:match("readable") and 1 or 0
    end,
    
    glob = function(pattern)
      return {"file1.lua", "file2.lua"}
    end,
    
    getqflist = function()
      return {
        { text = "Error in file.lua:10: syntax error", lnum = 10, filename = "file.lua" }
      }
    end,
    
    setqflist = function(list)
      -- Mock quickfix list setting
    end,
    
    getreg = function(reg)
      if reg == "+" then return "clipboard_content" end
      return "register_content"
    end,
    
    setreg = function(reg, value)
      -- Mock register setting
    end,
    
    getpos = function(mark)
      if mark == "'<" then return {0, 1, 1, 0} end
      if mark == "'>" then return {0, 3, 10, 0} end
      return {0, 1, 1, 0}
    end,
    
    mode = function(expr)
      return "n" -- Normal mode by default
    end,
    
    maparg = function(name, mode, abbr, dict)
      return dict and {} or ""
    end,
    
    tempname = function()
      return "/tmp/nvim_" .. math.random(100000, 999999)
    end,
    
    delete = function(fname)
      return 0 -- Success
    end,
    
    stdpath = function(type_)
      if type_ == "cache" then return "/tmp/nvim/cache" end
      if type_ == "config" then return "/tmp/nvim/config" end
      if type_ == "data" then return "/tmp/nvim/data" end
      return "/tmp/nvim"
    end,
    
    shellescape = function(str)
      return "'" .. str:gsub("'", "'\\''" ) .. "'"
    end,
    
    fnameescape = function(str)
      return str:gsub(" ", "\\ ")
    end,
    
    -- Job control
    jobstart = function(cmd, opts)
      local job_id = math.random(1000, 9999)
      test_state.mock_jobs[job_id] = {
        cmd = cmd,
        opts = opts,
        running = true
      }
      
      -- Simulate async job completion
      if opts and opts.on_exit then
        vim.defer_fn(function()
          opts.on_exit(job_id, 0)
        end, 10)
      end
      
      return job_id
    end,
    
    jobstop = function(job_id)
      if test_state.mock_jobs[job_id] then
        test_state.mock_jobs[job_id].running = false
      end
    end,
    
    jobwait = function(jobs, timeout)
      return {0} -- All jobs completed successfully
    end,
    
    chansend = function(id, data)
      -- Mock channel send
      return vim.tbl_count(data)
    end,
    
    chanclose = function(id, stream)
      -- Mock channel close
    end,
  }
end

-- Create notification mock
function M.create_notify_mock()
  local notifications = {}
  
  return function(msg, level, opts)
    table.insert(notifications, {
      message = msg,
      level = level,
      options = opts,
      timestamp = os.time()
    })
  end
end

-- Create command execution mock
function M.create_cmd_mock()
  local executed_commands = {}
  
  return function(command)
    table.insert(executed_commands, {
      command = command,
      timestamp = os.time()
    })
  end
end

-- Create keymap mock
function M.create_keymap_mock()
  local keymaps = {}
  
  return function(mode, lhs, rhs, opts)
    keymaps[mode .. ":" .. lhs] = {
      mode = mode,
      lhs = lhs,
      rhs = rhs,
      opts = opts or {}
    }
  end
end

-- Create loop/async operations mock
function M.create_loop_mock()
  return {
    new_timer = function()
      local timer_id = math.random(1000, 9999)
      test_state.mock_timers[timer_id] = {
        running = false,
        callback = nil
      }
      
      return {
        start = function(timeout, repeat_, callback)
          test_state.mock_timers[timer_id].running = true
          test_state.mock_timers[timer_id].callback = callback
          -- Simulate immediate execution for tests
          if callback then callback() end
        end,
        
        stop = function()
          test_state.mock_timers[timer_id].running = false
        end,
        
        close = function()
          test_state.mock_timers[timer_id] = nil
        end,
        
        _mock_id = timer_id
      }
    end,
    
    new_fs_event = function()
      local watcher_id = math.random(1000, 9999)
      test_state.mock_watchers[watcher_id] = {
        running = false,
        path = nil,
        callback = nil
      }
      
      return {
        start = function(path, flags, callback)
          test_state.mock_watchers[watcher_id].running = true
          test_state.mock_watchers[watcher_id].path = path
          test_state.mock_watchers[watcher_id].callback = callback
          return true, nil -- success, no error
        end,
        
        close = function()
          test_state.mock_watchers[watcher_id] = nil
        end,
        
        _mock_id = watcher_id
      }
    end,
    
    fs_stat = function(path)
      -- Mock file stats
      return {
        type = "file",
        size = 1024,
        mtime = { sec = os.time() }
      }
    end,
    
    now = function()
      return os.time() * 1000 -- Convert to milliseconds
    end
  }
end

-- Enhanced vim mock using the new system
local vim_mock = {
  -- Use the new API mock functions
  api = nil, -- Will be set in setup_vim_mock
  fn = nil,  -- Will be set in setup_vim_mock
  api = {
    nvim_create_user_command = function() end,
    nvim_create_buf = function() return 1 end,
    nvim_buf_set_option = function() end,
    nvim_win_get_cursor = function() return {1, 0} end,
    nvim_get_current_buf = function() return 1 end,
    nvim_buf_get_lines = function() return {"test line"} end,
    nvim_buf_set_lines = function() end,
    nvim_buf_get_name = function() return "test.lua" end,
    nvim_buf_get_option = function() return "lua" end,
    nvim_create_autocmd = function() end,
    nvim_open_win = function() return 1001 end,
    nvim_win_close = function() end,
    nvim_win_is_valid = function() return true end,
    nvim_win_set_option = function() end,
    nvim_buf_add_highlight = function() end,
  },
  fn = {
    expand = function() return "test_var" end,
    input = function() return "test_input" end,
    getqflist = function() return {} end,
    getreg = function() return "" end,
    jobstart = function() return 1234 end,
    chansend = function() end,
    chanclose = function() end,
    jobstop = function() end,
    getpos = function() return {0, 1, 1, 0} end,
    mode = function() return "n" end,
    fnamemodify = function() return "test.lua" end,
    stdpath = function() return "/tmp" end,
  },
  keymap = {
    set = function() end,
  },
  notify = function() end,
  log = {
    levels = {
      INFO = 1,
      WARN = 2,
      ERROR = 3,
    }
  },
  env = {
    ANTHROPIC_API_KEY = "test-key"
  },
  ui = {
    input = function(opts, callback)
      if callback then callback("test input") end
    end,
    select = function(items, opts, callback)
      if callback then callback(items[1], 1) end
    end,
  },
  split = function(str)
    return {str}
  end,
  tbl_extend = function(behavior, ...)
    local result = {}
    local tables = {...}
    for _, t in ipairs(tables) do
      if type(t) == "table" then
        for k, v in pairs(t) do
          result[k] = v
        end
      end
    end
    return result
  end,
  tbl_deep_extend = function(behavior, ...)
    local function deep_extend(t1, t2)
      local result = {}
      for k, v in pairs(t1 or {}) do
        result[k] = v
      end
      for k, v in pairs(t2 or {}) do
        if type(v) == "table" and type(result[k]) == "table" then
          result[k] = deep_extend(result[k], v)
        else
          result[k] = v
        end
      end
      return result
    end
    
    local tables = {...}
    local result = tables[1] or {}
    for i = 2, #tables do
      result = deep_extend(result, tables[i])
    end
    return result
  end,
  deepcopy = function(t)
    if type(t) ~= "table" then return t end
    local result = {}
    for k, v in pairs(t) do
      result[k] = vim.deepcopy(v)
    end
    return result
  end,
  loop = {
    new_timer = function()
      return {
        start = function() end,
        stop = function() end,
        close = function() end,
      }
    end
  },
  schedule_wrap = function(fn) return fn end,
  defer_fn = function(fn, delay) fn() end,
  schedule = function(fn) fn() end,
  json = {
    encode = function(data) return "{}" end,
    decode = function(str) return {} end,
  },
  o = {
    columns = 100,
    lines = 50,
  },
}

-- Set up vim global for testing
function M.setup_vim_mock()
  _G.vim = vim_mock
  return vim_mock
end

-- Create a test buffer context
function M.create_test_context()
  return {
    filename = "test.lua",
    filetype = "lua", 
    language = "lua",
    file_content = "function test()\n  return true\nend",
    selection = "return true",
    cursor_line = 2,
    cursor_col = 2,
    before_cursor = "function test()\n",
    after_cursor = "\nend",
    start_line = 2,
    end_line = 2,
  }
end

-- Mock API responses
function M.create_mock_api()
  return {
    request = function(prompt, context, callback)
      local response = "Mock AI response for: " .. (prompt or "")
      callback(response, nil)
    end,
    generate_code = function(description, context, callback)
      local code = "-- Generated code for: " .. description .. "\nfunction generated_function()\n  -- Implementation here\nend"
      callback(code, nil)
    end,
    explain_code = function(code, context, callback)
      local explanation = "This code does the following:\\n1. It defines a function\\n2. It returns a value"
      callback(explanation, nil)
    end,
    analyze_error = function(error_msg, context, callback)
      local analysis = "Error analysis for: " .. error_msg .. "\\nSuggested fix: Check line numbers"
      callback(analysis, nil)
    end,
    review_code = function(code, context, callback)
      local review = "Code review results:\\n- Code looks good\\n- Consider adding error handling"
      callback(review, nil)
    end,
    generate_tests = function(code, context, callback)
      local tests = "-- Generated tests\\ndescribe('test', function()\\n  it('should work', function()\\n    assert.equals(true, test())\\n  end)\\nend)"
      callback(tests, nil)
    end,
    suggest_refactoring = function(code, context, callback)
      local suggestions = "Refactoring suggestions:\\n1. Extract method\\n2. Rename variables"
      callback(suggestions, nil)
    end,
    cancel_requests = function() end,
    get_active_requests = function() return 0 end,
    check_auth_status = function()
      return {
        method = "api",
        available = true,
        status = "✅ Test API configured"
      }
    end,
  }
end

-- Mock UI functions  
function M.create_mock_ui()
  return {
    show_loading = function(title, message)
      return 9999 -- mock window ID
    end,
    hide_loading = function() end,
    show_response = function() end,
    show_error = function() end,
    show_success = function() end,
    input_dialog = function(prompt, callback, opts)
      if callback then callback("test input") end
    end,
    select_dialog = function(items, callback, opts)
      if callback then callback(items[1]) end
    end,
    get_current_context = function()
      return M.create_test_context()
    end,
    close_window = function() end,
    close_all_windows = function() end,
    cleanup = function() end,
    apply_code_suggestion = function() end,
  }
end

-- Mock config
function M.create_mock_config()
  return {
    setup = function() end,
    get = function()
      return {
        api = {
          key = "test-key",
          model = "claude-3-5-sonnet-20241022",
          base_url = "https://api.anthropic.com/v1",
          max_tokens = 4096,
          temperature = 0.1,
          timeout = 30000,
          use_cli = false,
        },
        features = {
          completion = { enabled = true, max_context_lines = 100 },
          code_writing = { enabled = true },
          debugging = { enabled = true },
          code_review = { enabled = true, max_file_size = 10000 },
          testing = { enabled = true },
          refactoring = { enabled = true },
        },
        ui = {
          float_border = "rounded",
          float_width = 0.8,
          float_height = 0.6,
          progress_indicator = true,
          syntax_highlighting = true,
          auto_close_delay = 5000,
        },
        keymaps = {
          commands = {
            write_function = "<leader>cw",
            implement_todo = "<leader>ci",
          }
        },
        prompts = {
          code_completion = "Complete this code:",
          code_generation = "Generate code:",
          code_explanation = "Explain this code:",
          debug_analysis = "Debug this error:",
          code_review = "Review this code:",
          test_generation = "Generate tests:",
          refactoring = "Suggest refactoring:",
        },
      }
    end,
    update = function() end,
    validate = function() end,
    setup_keymaps = function() end,
  }
end

-- Helper to capture function calls
function M.create_spy()
  local calls = {}
  return {
    fn = function(...)
      table.insert(calls, {...})
    end,
    calls = calls,
    call_count = function() return #calls end,
    was_called = function() return #calls > 0 end,
    was_called_with = function(...)
      local args = {...}
      for _, call in ipairs(calls) do
        local match = true
        for i, arg in ipairs(args) do
          if call[i] ~= arg then
            match = false
            break
          end
        end
        if match then return true end
      end
      return false
    end,
  }
end

-- Wait for async operations (mock)
function M.wait_for_async(timeout)
  timeout = timeout or 100
  -- In real tests, this might use vim.wait or similar
  -- For now, just execute immediately
  return true
end

-- Load test fixtures
function M.load_fixture(name)
  local fixture_path = "tests/fixtures/" .. name .. ".lua"
  local file = io.open(fixture_path, "r")
  if not file then
    return nil, "Fixture not found: " .. name
  end
  local content = file:read("*all")
  file:close()
  return content
end

return M