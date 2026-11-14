#!/bin/bash

# Link dotfiles
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
ln -sf $SCRIPT_DIR/.tmux.conf $HOME/.tmux.conf
ln -sf $SCRIPT_DIR/.dotfile.bash $HOME/.dotfile.bash
ln -sf $SCRIPT_DIR/.vimrc $HOME/.vimrc

# Add line in bashrc to source file in git repo
LINE='source "$HOME/.dotfile.bash"'
FILE="$HOME/.bashrc"
grep -qF -- "$LINE" "$FILE" || echo "$LINE" >> "$FILE"

# Map Alt+1..9 for GNOME app switching (idempotent & safe on non-GNOME systems)
if command -v gsettings >/dev/null 2>&1; then
    if gsettings list-schemas | grep -q "^org.gnome.shell.keybindings$"; then
        for i in {1..9}; do
            gsettings set org.gnome.shell.keybindings switch-to-application-$i "['<Alt>$i']"
        done
    fi

    if gsettings list-schemas | grep -q "^org.gnome.shell.extensions.dash-to-dock$"; then
        for i in {1..9}; do
            gsettings set org.gnome.shell.extensions.dash-to-dock app-hotkey-$i "['<Alt>$i']"
        done
    fi
fi

# Run Touhou Mouse setup if on Ubuntu/Debian
if [ -x "$SCRIPT_DIR/touhou_mouse/touhou_mouse_setup.sh" ] && command -v apt >/dev/null 2>&1; then
    "$SCRIPT_DIR/touhou_mouse/touhou_mouse_setup.sh"
fi
