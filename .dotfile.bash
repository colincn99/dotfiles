stty -ixon
bind -s 'set completion-ignore-case on'

# Neovim aliases
if command -v nvim &> /dev/null; then
  alias bvim="nvim -u ~/.config/nvim_backup/init.lua"
  alias novim="nvim -u NONE"
  alias pvim="nvim -S ~/.prev_session"
  export EDITOR="nvim -u NONE"
fi

# Start bash in tmux
if command -v tmux &> /dev/null && [ -n "$PS1" ] && [[ ! "$TERM" =~ tmux ]] && [ -z "$TMUX" ]; then
  cd
  exec tmux
  echo "lol"
fi

# Open man of typed command in tmux split
if command -v tmux &> /dev/null && [ -n "$TMUX" ]; then
  function man-split {
    tmux split-window -h "man ${READLINE_LINE%% *}"
  }
  bind -x '"\C-o":"man-split"'
fi

# File and url opening aliases
if [[ $(uname -r) =~ WSL ]]; then
  alias browser="/mnt/c/Program\ Files/Google/Chrome/Application/chrome.exe"
  alias o="explorer.exe"
else
  alias o="xdg-open"
fi
alias gh="o \`git remote -v | grep fetch | awk 'NR==1{print \$2}' | sed 's/git@/http:\/\//' | sed 's/com:/com\//'\`| head -n1"

# Set up fzf key bindings and fuzzy completion
if command -v fzf &> /dev/null; then
  source /usr/share/doc/fzf/examples/key-bindings.bash
  source /usr/share/doc/fzf/examples/completion.bash
fi

