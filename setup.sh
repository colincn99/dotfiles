#!/bin/bash

# Link dotfiles
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
ln -sf $SCRIPT_DIR/.tmux.conf $HOME/.tmux.conf
ln -sf $SCRIPT_DIR/.dotfile.bash $HOME/.dotfile.bash

# Add line in bashrc to source file in git repo
LINE='source "$HOME/.dotfile.bash"'
FILE="$HOME/.bashrc"
grep -qF -- "$LINE" "$FILE" || echo "$LINE" >> "$FILE"
