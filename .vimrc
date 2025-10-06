set nocompatible
filetype plugin indent on
set relativenumber

" tabs
set tabstop=4
set shiftwidth=4
set softtabstop=4
set expandtab

set incsearch
set ignorecase
set smartcase
set showmatch
set mouse=a

" Keymaps
let mapleader = " "

nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l

nnoremap <C-Up> :<C-u>resize -2<CR>
nnoremap <C-Down> :<C-u>resize +2<CR>
nnoremap <C-Left> :<C-u>vertical resize -2<CR>
nnoremap <C-Right> :<C-u>vertical resize +2<CR>

nnoremap <S-l> :<C-u>tabn<CR>
nnoremap <S-h> :<C-u>tabp<CR>
nnoremap <C-n> :<C-u>tabnew %<CR>
nnoremap <leader>x :<C-u>tabclose<CR>

vnoremap < <gv^
vnoremap > >gv^

vnoremap p _dP

set ttimeout ttimeoutlen=5
nnoremap <esc>h 12h
nnoremap <esc>j 6j
nnoremap <esc>k 6k
nnoremap <esc>l 12l
