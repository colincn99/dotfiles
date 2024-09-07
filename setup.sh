#!/bin/bash

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
ln -sf $SCRIPT_DIR/.bashrc $HOME/.bashrc
ln -sf $SCRIPT_DIR/.tmux.conf $HOME/.tmux.conf
