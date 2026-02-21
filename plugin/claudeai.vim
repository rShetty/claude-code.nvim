" Claude Code Neovim Plugin
" Vim compatibility layer and plugin initialization

if exists('g:loaded_claudeai') || !has('nvim-0.7.0')
  finish
endif

let g:loaded_claudeai = 1

" Default configuration (can be overridden by user)
if !exists('g:claudeai_config')
  let g:claudeai_config = {}
endif

" Initialize plugin on VimEnter (ensures nvim is fully loaded)
augroup ClaudeAIInit
  autocmd!
  autocmd VimEnter * lua require('claudeai').setup(vim.g.claudeai_config or {})
augroup END

" Vim-style configuration functions for users who prefer vimscript
function! ClaudeAISetup(config)
  let g:claudeai_config = a:config
  lua require('claudeai').setup(vim.g.claudeai_config)
endfunction

" Convenience function for quick setup
function! ClaudeAIQuickSetup(api_key)
  call ClaudeAISetup({'api': {'key': a:api_key}})
endfunction

" Status function accessible from Vim
function! ClaudeAIStatus()
  lua require('claudeai').show_status()
endfunction

" Help function accessible from Vim  
function! ClaudeAIHelp()
  lua require('claudeai').show_help()
endfunction

" Health check registration
function! health#claudeai#check() abort
  lua require('claudeai.health').check()
endfunction
