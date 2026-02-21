" Claude Code Neovim Plugin
" Vim compatibility layer and plugin initialization

if exists('g:loaded_claude_code') || !has('nvim-0.7.0')
  finish
endif

let g:loaded_claude_code = 1

" Default configuration (can be overridden by user)
if !exists('g:claude_code_config')
  let g:claude_code_config = {}
endif

" Initialize plugin on VimEnter (ensures nvim is fully loaded)
augroup ClaudeCodeInit
  autocmd!
  autocmd VimEnter * lua require('claude-code').setup(vim.g.claude_code_config or {})
augroup END

" Vim-style configuration functions for users who prefer vimscript
function! ClaudeCodeSetup(config)
  let g:claude_code_config = a:config
  lua require('claude-code').setup(vim.g.claude_code_config)
endfunction

" Convenience function for quick setup
function! ClaudeCodeQuickSetup(api_key)
  call ClaudeCodeSetup({'api': {'key': a:api_key}})
endfunction

" Status function accessible from Vim
function! ClaudeCodeStatus()
  lua require('claude-code').show_status()
endfunction

" Help function accessible from Vim  
function! ClaudeCodeHelp()
  lua require('claude-code').show_help()
endfunction

" Health check - will be handled by the health.lua module
