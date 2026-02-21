-- Git integration utilities for Claude Code Neovim Plugin
-- Provides git project detection, status, and context for better code analysis
local config = require("claude-code.config")

local M = {}

-- Internal state and cache
local git_state = {
  enabled = false,
  cache = {}, -- project_root -> { status, branch, last_check }
  cache_ttl = 30000, -- 30 seconds cache TTL
  current_project = nil,
}

-- Default git integration configuration
local git_defaults = {
  enabled = true,
  auto_cd_root = true,
  include_git_context = true,
  status_in_prompts = true,
  branch_in_prompts = true,
  recent_commits_count = 5,
  cache_duration = 30, -- seconds
  ignore_submodules = false,
  detect_worktrees = true,
}

-- Initialize git integration
function M.setup(user_config)
  local cfg = vim.tbl_deep_extend("force", git_defaults, user_config or {})
  config.update({ git = cfg })
  
  if cfg.enabled then
    git_state.enabled = true
    git_state.cache_ttl = cfg.cache_duration * 1000
    M.setup_autocommands()
    M.setup_commands()
  end
end

-- Setup autocommands for git integration
function M.setup_autocommands()
  local group = vim.api.nvim_create_augroup("ClaudeCodeGit", { clear = true })
  
  -- Update git context when entering buffers
  vim.api.nvim_create_autocmd({ "BufEnter", "DirChanged" }, {
    group = group,
    callback = function()
      if git_state.enabled then
        M.update_current_project()
      end
    end,
  })
  
  -- Clear cache when git operations might have occurred
  vim.api.nvim_create_autocmd({ "FocusGained", "BufWritePost" }, {
    group = group,
    callback = function()
      if git_state.enabled then
        M.invalidate_cache()
      end
    end,
  })
  
  -- Cleanup on exit
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = function()
      M.cleanup()
    end,
  })
end

-- Setup git-related commands
function M.setup_commands()
  -- Show git status
  vim.api.nvim_create_user_command("ClaudeGitStatus", function()
    M.show_git_status()
  end, {
    desc = "Show git status for Claude Code",
  })
  
  -- Show git context
  vim.api.nvim_create_user_command("ClaudeGitContext", function()
    M.show_git_context()
  end, {
    desc = "Show git context information",
  })
  
  -- Navigate to git root
  vim.api.nvim_create_user_command("ClaudeGitRoot", function()
    M.cd_to_git_root()
  end, {
    desc = "Change to git root directory",
  })
  
  -- Clear git cache
  vim.api.nvim_create_user_command("ClaudeGitClearCache", function()
    M.clear_cache()
  end, {
    desc = "Clear git information cache",
  })
end

-- Find git root directory
function M.find_git_root(start_path)
  start_path = start_path or vim.fn.expand("%:p:h")
  if start_path == "" then
    start_path = vim.fn.getcwd()
  end
  
  local current_dir = start_path
  local max_depth = 20 -- Prevent infinite loops
  local depth = 0
  
  while current_dir ~= "/" and depth < max_depth do
    -- Check for .git directory
    if vim.fn.isdirectory(current_dir .. "/.git") == 1 then
      return current_dir
    end
    
    -- Check for .git file (git worktrees)
    if config.get().git.detect_worktrees and vim.fn.filereadable(current_dir .. "/.git") == 1 then
      return current_dir
    end
    
    current_dir = vim.fn.fnamemodify(current_dir, ":h")
    depth = depth + 1
  end
  
  return nil
end

-- Check if directory is a git repository
function M.is_git_repo(path)
  path = path or vim.fn.getcwd()
  return M.find_git_root(path) ~= nil
end

-- Get git information for a project
function M.get_git_info(project_root)
  project_root = project_root or M.find_git_root()
  if not project_root then
    return nil
  end
  
  -- Check cache first
  local cached = git_state.cache[project_root]
  local now = vim.loop.now()
  
  if cached and (now - cached.last_check) < git_state.cache_ttl then
    return cached
  end
  
  -- Gather git information
  local git_info = {
    root = project_root,
    last_check = now,
  }
  
  -- Get current branch
  git_info.branch = M.get_current_branch(project_root)
  
  -- Get git status
  git_info.status = M.get_git_status(project_root)
  
  -- Get recent commits
  if config.get().git.recent_commits_count > 0 then
    git_info.recent_commits = M.get_recent_commits(project_root, config.get().git.recent_commits_count)
  end
  
  -- Get remote information
  git_info.remote = M.get_remote_info(project_root)
  
  -- Get current HEAD information
  git_info.head = M.get_head_info(project_root)
  
  -- Cache the information
  git_state.cache[project_root] = git_info
  
  return git_info
end

-- Get current git branch
function M.get_current_branch(project_root)
  if not project_root then
    return nil
  end
  
  -- Try git symbolic-ref first (works for normal branches)
  local handle = io.popen("cd " .. vim.fn.shellescape(project_root) .. " && git symbolic-ref --short HEAD 2>/dev/null")
  if handle then
    local branch = handle:read("*a"):gsub("\n", "")
    handle:close()
    
    if branch and branch ~= "" then
      return branch
    end
  end
  
  -- Fallback to git rev-parse (works for detached HEAD)
  handle = io.popen("cd " .. vim.fn.shellescape(project_root) .. " && git rev-parse --short HEAD 2>/dev/null")
  if handle then
    local commit = handle:read("*a"):gsub("\n", "")
    handle:close()
    
    if commit and commit ~= "" then
      return "detached@" .. commit
    end
  end
  
  return nil
end

-- Get git status information
function M.get_git_status(project_root)
  if not project_root then
    return nil
  end
  
  local cmd = "cd " .. vim.fn.shellescape(project_root) .. " && git status --porcelain=v1 2>/dev/null"
  local handle = io.popen(cmd)
  if not handle then
    return nil
  end
  
  local status = {
    modified = {},
    added = {},
    deleted = {},
    renamed = {},
    copied = {},
    untracked = {},
    staged = {},
    conflicts = {},
  }
  
  for line in handle:lines() do
    if line and line ~= "" then
      local index_status = line:sub(1, 1)
      local worktree_status = line:sub(2, 2)
      local filename = line:sub(4)
      
      -- Staged changes
      if index_status == "A" then
        table.insert(status.staged, filename)
        table.insert(status.added, filename)
      elseif index_status == "M" then
        table.insert(status.staged, filename)
        table.insert(status.modified, filename)
      elseif index_status == "D" then
        table.insert(status.staged, filename)
        table.insert(status.deleted, filename)
      elseif index_status == "R" then
        table.insert(status.staged, filename)
        table.insert(status.renamed, filename)
      elseif index_status == "C" then
        table.insert(status.staged, filename)
        table.insert(status.copied, filename)
      end
      
      -- Worktree changes
      if worktree_status == "M" then
        table.insert(status.modified, filename)
      elseif worktree_status == "D" then
        table.insert(status.deleted, filename)
      elseif worktree_status == "?" then
        table.insert(status.untracked, filename)
      elseif worktree_status == "U" or index_status == "U" then
        table.insert(status.conflicts, filename)
      end
    end
  end
  
  handle:close()
  
  -- Calculate summary counts
  status.summary = {
    staged_count = #status.staged,
    modified_count = #status.modified,
    deleted_count = #status.deleted,
    untracked_count = #status.untracked,
    conflicts_count = #status.conflicts,
    total_changes = #status.staged + #status.modified + #status.deleted + #status.untracked,
  }
  
  return status
end

-- Get recent commits
function M.get_recent_commits(project_root, count)
  if not project_root or count <= 0 then
    return {}
  end
  
  local cmd = string.format(
    'cd %s && git log --oneline --no-merges -%d --format="%%h|%%s|%%an|%%ar" 2>/dev/null',
    vim.fn.shellescape(project_root),
    count
  )
  
  local handle = io.popen(cmd)
  if not handle then
    return {}
  end
  
  local commits = {}
  for line in handle:lines() do
    if line and line ~= "" then
      local parts = vim.split(line, "|", { plain = true })
      if #parts >= 4 then
        table.insert(commits, {
          hash = parts[1],
          message = parts[2],
          author = parts[3],
          date = parts[4],
        })
      end
    end
  end
  
  handle:close()
  return commits
end

-- Get remote information
function M.get_remote_info(project_root)
  if not project_root then
    return nil
  end
  
  local cmd = "cd " .. vim.fn.shellescape(project_root) .. " && git remote -v 2>/dev/null"
  local handle = io.popen(cmd)
  if not handle then
    return nil
  end
  
  local remotes = {}
  for line in handle:lines() do
    if line and line ~= "" then
      local parts = vim.split(line, "\t")
      if #parts >= 2 then
        local name = parts[1]
        local url_and_type = vim.split(parts[2], " ")
        if #url_and_type >= 2 then
          local url = url_and_type[1]
          local type = url_and_type[2]:gsub("[()]", "")
          
          if not remotes[name] then
            remotes[name] = {}
          end
          remotes[name][type] = url
        end
      end
    end
  end
  
  handle:close()
  
  -- Get primary remote (usually origin)
  local primary_remote = remotes.origin or next(remotes)
  if primary_remote then
    return {
      all_remotes = remotes,
      primary = {
        name = "origin",
        url = primary_remote.fetch or primary_remote.push,
      }
    }
  end
  
  return nil
end

-- Get HEAD information
function M.get_head_info(project_root)
  if not project_root then
    return nil
  end
  
  local cmd = "cd " .. vim.fn.shellescape(project_root) .. " && git rev-parse HEAD 2>/dev/null"
  local handle = io.popen(cmd)
  if not handle then
    return nil
  end
  
  local commit_hash = handle:read("*a"):gsub("\n", "")
  handle:close()
  
  if commit_hash and commit_hash ~= "" then
    return {
      full_hash = commit_hash,
      short_hash = commit_hash:sub(1, 7),
    }
  end
  
  return nil
end

-- Update current project context
function M.update_current_project()
  local project_root = M.find_git_root()
  if project_root ~= git_state.current_project then
    git_state.current_project = project_root
    
    -- Auto CD to git root if enabled
    if project_root and config.get().git.auto_cd_root then
      M.cd_to_git_root(project_root)
    end
  end
end

-- Change directory to git root
function M.cd_to_git_root(project_root)
  project_root = project_root or M.find_git_root()
  if not project_root then
    vim.notify("Not in a git repository", vim.log.levels.WARN)
    return false
  end
  
  local current_dir = vim.fn.getcwd()
  if current_dir ~= project_root then
    vim.cmd("cd " .. vim.fn.fnameescape(project_root))
    vim.notify("Changed to git root: " .. project_root, vim.log.levels.INFO)
    return true
  end
  
  return false
end

-- Get git context for Claude prompts
function M.get_git_context(project_root)
  project_root = project_root or M.find_git_root()
  if not project_root then
    return nil
  end
  
  local git_info = M.get_git_info(project_root)
  if not git_info then
    return nil
  end
  
  local cfg = config.get().git
  local context = {
    project_root = project_root,
  }
  
  -- Add branch information
  if cfg.branch_in_prompts and git_info.branch then
    context.branch = git_info.branch
  end
  
  -- Add status information
  if cfg.status_in_prompts and git_info.status then
    local status = git_info.status
    if status.summary.total_changes > 0 then
      context.status = {
        staged = status.summary.staged_count,
        modified = status.summary.modified_count,
        untracked = status.summary.untracked_count,
        conflicts = status.summary.conflicts_count,
        files = {
          modified = status.modified,
          staged = status.staged,
          untracked = status.untracked,
        }
      }
    end
  end
  
  -- Add recent commits
  if cfg.recent_commits_count > 0 and git_info.recent_commits then
    context.recent_commits = git_info.recent_commits
  end
  
  -- Add remote information
  if git_info.remote then
    context.remote = git_info.remote.primary
  end
  
  return context
end

-- Format git context for inclusion in prompts
function M.format_git_context(context)
  context = context or M.get_git_context()
  if not context then
    return ""
  end
  
  local lines = {}
  
  -- Project information
  table.insert(lines, "Git Repository Context:")
  table.insert(lines, "- Project Root: " .. vim.fn.fnamemodify(context.project_root, ":t"))
  
  -- Branch information
  if context.branch then
    table.insert(lines, "- Current Branch: " .. context.branch)
  end
  
  -- Status information
  if context.status then
    local status_summary = {}
    if context.status.staged > 0 then
      table.insert(status_summary, context.status.staged .. " staged")
    end
    if context.status.modified > 0 then
      table.insert(status_summary, context.status.modified .. " modified")
    end
    if context.status.untracked > 0 then
      table.insert(status_summary, context.status.untracked .. " untracked")
    end
    if context.status.conflicts > 0 then
      table.insert(status_summary, context.status.conflicts .. " conflicts")
    end
    
    if #status_summary > 0 then
      table.insert(lines, "- Status: " .. table.concat(status_summary, ", "))
    end
  end
  
  -- Recent commits
  if context.recent_commits and #context.recent_commits > 0 then
    table.insert(lines, "- Recent Commits:")
    for i, commit in ipairs(context.recent_commits) do
      if i <= 3 then -- Limit to 3 most recent for brevity
        table.insert(lines, string.format("  • %s: %s (%s)", 
          commit.hash, commit.message:sub(1, 50), commit.author))
      end
    end
  end
  
  -- Remote information
  if context.remote then
    table.insert(lines, "- Remote: " .. (context.remote.url or "unknown"))
  end
  
  return table.concat(lines, "\n")
end

-- Show git status
function M.show_git_status()
  local git_info = M.get_git_info()
  if not git_info then
    vim.notify("Not in a git repository", vim.log.levels.WARN)
    return
  end
  
  local status_lines = {
    "Git Repository Status",
    "====================",
    "",
    "Project: " .. vim.fn.fnamemodify(git_info.root, ":t"),
    "Branch: " .. (git_info.branch or "unknown"),
    "",
  }
  
  if git_info.status then
    local status = git_info.status
    table.insert(status_lines, "Changes Summary:")
    table.insert(status_lines, "- Staged: " .. status.summary.staged_count)
    table.insert(status_lines, "- Modified: " .. status.summary.modified_count)
    table.insert(status_lines, "- Deleted: " .. status.summary.deleted_count)
    table.insert(status_lines, "- Untracked: " .. status.summary.untracked_count)
    table.insert(status_lines, "- Conflicts: " .. status.summary.conflicts_count)
    table.insert(status_lines, "")
    
    -- Show specific files if there are changes
    if status.summary.total_changes > 0 then
      if #status.staged > 0 then
        table.insert(status_lines, "Staged Files:")
        for _, file in ipairs(status.staged) do
          table.insert(status_lines, "  + " .. file)
        end
        table.insert(status_lines, "")
      end
      
      if #status.modified > 0 then
        table.insert(status_lines, "Modified Files:")
        for _, file in ipairs(status.modified) do
          table.insert(status_lines, "  ~ " .. file)
        end
        table.insert(status_lines, "")
      end
      
      if #status.untracked > 0 then
        table.insert(status_lines, "Untracked Files:")
        for _, file in ipairs(status.untracked) do
          table.insert(status_lines, "  ? " .. file)
        end
      end
    else
      table.insert(status_lines, "Working tree clean ✅")
    end
  end
  
  require("claude-code.ui").show_response(status_lines, {
    title = "Git Status",
    filetype = "text",
  })
end

-- Show full git context
function M.show_git_context()
  local context = M.get_git_context()
  if not context then
    vim.notify("Not in a git repository", vim.log.levels.WARN)
    return
  end
  
  local formatted_context = M.format_git_context(context)
  
  require("claude-code.ui").show_response(formatted_context, {
    title = "Git Context",
    filetype = "text",
  })
end

-- Invalidate cache
function M.invalidate_cache(project_root)
  if project_root then
    git_state.cache[project_root] = nil
  else
    git_state.cache = {}
  end
end

-- Clear all cache
function M.clear_cache()
  git_state.cache = {}
  vim.notify("Git cache cleared", vim.log.levels.INFO)
end

-- Check if git integration is enabled
function M.is_enabled()
  return git_state.enabled
end

-- Get current project root
function M.get_current_project()
  return git_state.current_project
end

-- Get all cached projects
function M.get_cached_projects()
  local projects = {}
  for project_root, _ in pairs(git_state.cache) do
    table.insert(projects, project_root)
  end
  return projects
end

-- Cleanup function
function M.cleanup()
  git_state = {
    enabled = false,
    cache = {},
    cache_ttl = 30000,
    current_project = nil,
  }
end

return M