# .bashrc - Managed by dotfiles (GNU Stow)

# Source global definitions
if [ -f /etc/bashrc ]; then
    . /etc/bashrc
fi

# User specific environment
export PATH="$HOME/.local/bin:$HOME/bin:$PATH"
export EDITOR="nvim"
export VISUAL="nvim"

# Terminal appearance
export TERM=xterm-256color

# Useful Aliases
alias l="ls -lah --color=auto"
alias ll="ls -l --color=auto"
alias la="ls -A --color=auto"
alias grep="grep --color=auto"
alias gs="git status -s"
alias gl="git pull"
alias gp="git push"

# Quick dotfiles manager alias
if [ -f "$HOME/dev/dotfiles-fedora/Justfile" ]; then
    alias dotfiles="just -f $HOME/dev/dotfiles-fedora/Justfile"
elif [ -f "$HOME/dotfiles-fedora/Justfile" ]; then
    alias dotfiles="just -f $HOME/dotfiles-fedora/Justfile"
elif [ -f "$HOME/dotfiles/Justfile" ]; then
    alias dotfiles="just -f $HOME/dotfiles/Justfile"
fi

# Load local machine bash configurations if present
if [ -f "$HOME/.bashrc.local" ]; then
    source "$HOME/.bashrc.local"
fi
