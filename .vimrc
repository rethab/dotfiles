" Use Vim settings, rather than Vi settings (much better!).
" This must be first, because it changes other options as a side effect.
set nocompatible

execute pathogen#infect()

set gfn=Monospace\ 12
set title " set title in terminal (filename)
set noerrorbells " stfu
set incsearch "Lookahead as search pattern is specified
set ignorecase "generally ignore cases in search
set smartcase " do not ignore cases if an uppercase is used
set number
set smartindent " position cursor and braces correctly
set autowrite " automatically write changes when jumping between files
set autoread " Always reload external changes
set hls "highlight search
set encoding=utf-8
set noshowmode " Suppress mode changes messages
set scrolloff=2 " Begin scrolling when 2 lines before bottom
set showcmd " Show command in bottom area

" allow backspacing over everything in insert mode
set backspace=indent,eol,start

" In many terminal emulators the mouse works just fine, thus enable it.
if has('mouse')
  set mouse=a
endif

" Generally sane behavior
set tabstop=8 "A tab is 8 spaces
set expandtab "Always uses spaces instead of tabs
set softtabstop=2 "Insert 4 spaces when tab is pressed
set shiftwidth=2 "An indent is 4 spaces
set smarttab "Indent instead of tab at start of line
set shiftround "Round spaces to nearest shiftwidth multiple
set nojoinspaces "Don't convert spaces to tabs

" Visual block mode forms nices squares
set virtualedit=block

"enable type specific features
syntax on
filetype plugin on

" Use persistent undo
if has('persistent_undo')
    set undodir=$HOME/.backup/.VIM_UNDO_FILES
    set undolevels=5000
    set undofile
endif

" zR open all, zM close all, zc close, zo open
set foldmethod=syntax
set foldlevelstart=99

" Common mistypings
iab   stauts status
iab   retrun return
iab chekcout checkout
iab    teh the

"disable search highlights by hitting return (must be after unmapping CR from NERDTree)
nnoremap <CR> :noh<CR><CR>


" go to end of line from insert mode
imap <C-l> <ESC>A
imap <C-o> <ESC>o

" use ' as `. backquote brings you to the exact position of a mark rather than just the line
nnoremap ' `
nnoremap ` '

"directory for swap files
set directory=~/.backup,/tmp

" use jj to leave insert mode
:imap jj <esc>

" use kk to leave insert mode and save
:imap kk <esc>:w<cr>

"scroll up and down with J and K
nnoremap <C-j> <C-e>
nnoremap <C-k> <C-y>
" Scroll page with space
nnoremap <Space> <PageDown>
" quit and save with YY
nnoremap YY ZZ

" NERDTree Settings
" close vim if nerdtree is the last open window
autocmd bufenter * if (winnr("$") == 1 && exists("b:NERDTreeType") && b:NERDTreeType == "primary") | q | endif
" go to tree with with <C-h>
nnoremap <C-h> <C-w><C-w>
" go to file with with <C-l>
nnoremap <C-l> <C-w><C-w>
" toggle with <C-n>
map  <C-n> :NERDTreeToggle<CR>
" open current file in nerdtree
map <C-f> :NERDTreeFind<CR>

" use xmllint to format xml
:set equalprg=xmllint\ --format\ -

" Syntasic
set statusline+=%#warningmsg#
set statusline+=%{SyntasticStatuslineFlag()}
set statusline+=%*
