" ── Stop accidental suspends (C-z is a menace)
nnoremap <C-z> <nop>
inoremap <C-z> <nop>
vnoremap <C-z> <nop>

" ── Visual sanity
set number
set relativenumber
set cursorline
set showcmd
set showmode
set signcolumn=yes
set termguicolors
syntax on

colorscheme desert
set background=dark

" ── Transparency
highlight Normal       ctermbg=NONE guibg=NONE
highlight NonText      ctermbg=NONE guibg=NONE
highlight LineNr       ctermbg=NONE guibg=NONE
highlight CursorLineNr ctermbg=NONE guibg=NONE
highlight SignColumn   ctermbg=NONE guibg=NONE
highlight VertSplit    ctermbg=NONE guibg=NONE
highlight StatusLine   ctermbg=NONE guibg=NONE
highlight StatusLineNC ctermbg=NONE guibg=NONE
highlight EndOfBuffer  ctermbg=NONE guibg=NONE
highlight CursorLine   ctermbg=NONE guibg=NONE

