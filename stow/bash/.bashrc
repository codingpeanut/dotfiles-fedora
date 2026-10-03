# .bashrc - Managed by dotfiles (GNU Stow)

# Source global definitions
if [ -f /etc/bashrc ]; then
    . /etc/bashrc
fi

# User specific environment
export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:$HOME/bin:$PATH"
export EDITOR="nvim"
export VISUAL="nvim"

# Chinese Input Method (Fcitx5)
export GTK_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx
export XMODIFIERS=@im=fcitx

# Terminal appearance
export TERM=xterm-256color

# Useful Aliases
alias grep="grep --color=auto"
alias gs="git status -s"
alias gl="git pull"
alias gp="git push"

# Modern ls replacement (eza)
if command -v eza >/dev/null 2>&1; then
    alias ls="eza --icons"
    alias l="eza -lah --icons"
    alias ll="eza -l --icons"
    alias la="eza -a --icons"
    alias tree="eza --tree --icons"
else
    alias l="ls -lah --color=auto"
    alias ll="ls -l --color=auto"
    alias la="ls -A --color=auto"
fi

# Editor integration (link vi/vim to neovim)
alias vim="nvim"
alias vi="nvim"
alias v="nvim"

# System information
alias neofetch="fastfetch"

# Quick dotfiles manager alias
if [ -f "$HOME/dev/dotfiles-fedora/Justfile" ]; then
    alias dotfiles="just -f $HOME/dev/dotfiles-fedora/Justfile"
elif [ -f "$HOME/dotfiles-fedora/Justfile" ]; then
    alias dotfiles="just -f $HOME/dotfiles-fedora/Justfile"
elif [ -f "$HOME/dotfiles/Justfile" ]; then
    alias dotfiles="just -f $HOME/dotfiles/Justfile"
fi

# FZF key bindings & fuzzy tab completion (**<TAB>, Ctrl+R, Ctrl+T, Alt+C)
if [ -f /usr/share/fzf/shell/key-bindings.bash ]; then
    source /usr/share/fzf/shell/key-bindings.bash
fi
if [ -f /usr/share/fzf/shell/completion.bash ]; then
    source /usr/share/fzf/shell/completion.bash
fi

# FZF Options with live preview (bat for files, eza for directories)
export FZF_DEFAULT_OPTS="--height 40% --layout=reverse --border --prompt='❯ '"
export FZF_CTRL_T_OPTS="--preview 'bat --style=numbers --color=always --line-range :500 {} 2>/dev/null || cat {}' --preview-window right:50%"
export FZF_ALT_C_OPTS="--preview 'eza --tree --color=always {} 2>/dev/null | head -100' --preview-window right:50%"

# Zoxide (smart cd jump)
if command -v zoxide >/dev/null 2>&1; then
    eval "$(zoxide init bash)"
fi

# Starship prompt decoration
if command -v starship >/dev/null 2>&1; then
    eval "$(starship init bash)"
fi

# Load local machine bash configurations if present
if [ -f "$HOME/.bashrc.local" ]; then
    source "$HOME/.bashrc.local"
fi
