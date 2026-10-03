# Justfile - Declarative dotfiles & system manager
# Inspired by NixOS declarative workflow for Fedora

default:
    @just --list

# Apply full configuration (system packages + dotfiles + user services)
apply *args:
    ansible-playbook -i ansible/inventory.ini ansible/playbook.yml --ask-become-pass {{ args }}

# Sync and apply dotfiles symlinks via GNU Stow
dotfiles *args:
    ansible-playbook -i ansible/inventory.ini ansible/playbook.yml --tags dotfiles {{ args }}

# Run only system-level configuration (DNF packages, COPR repos, systemd services)
system *args:
    ansible-playbook -i ansible/inventory.ini ansible/playbook.yml --tags system --ask-become-pass {{ args }}

# Run only user-level configuration (dotfiles, flatpaks, user services)
user *args:
    ansible-playbook -i ansible/inventory.ini ansible/playbook.yml --tags user {{ args }}

# Install user Flatpak applications directly with live progress bar
flatpaks:
    @echo "==> Ensuring user Flathub remote is configured..."
    @flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    @flatpak remote-modify --user flathub --enable --no-filter
    @echo "==> Installing declarative user Flatpaks (live interactive progress bar)..."
    flatpak install --user -y flathub com.discordapp.Discord

# Accelerate Flathub downloads by switching to Asian mirror (SJTU)
mirror-flathub:
    @echo "==> Switching user Flathub to SJTU mirror (https://mirror.sjtu.edu.cn/flathub)..."
    flatpak remote-modify --user flathub --url=https://mirror.sjtu.edu.cn/flathub
    @echo "==> Switched to mirror. Run 'just flatpaks' to test speed."

# Reset user Flathub to official global CDN
reset-flathub:
    @echo "==> Resetting user Flathub to official global CDN..."
    flatpak remote-modify --user flathub --url=https://dl.flathub.org/repo
    @echo "==> Flathub reset to default."

# Fast direct Stow re-link for all packages without running Ansible
stow:
    @echo "==> Stowing all packages into $HOME..."
    @if [ -f "$$HOME/.bashrc" ] && [ ! -L "$$HOME/.bashrc" ]; then \
        echo "Backing up existing regular ~/.bashrc to ~/.bashrc.bak..."; \
        mv "$$HOME/.bashrc" "$$HOME/.bashrc.bak"; \
    fi
    @if [ -f "$$HOME/.vimrc" ] && [ ! -L "$$HOME/.vimrc" ]; then \
        echo "Backing up existing regular ~/.vimrc to ~/.vimrc.bak..."; \
        mv "$$HOME/.vimrc" "$$HOME/.vimrc.bak"; \
    fi
    @cd stow && for pkg in */; do \
        pkg_name=$${pkg%/}; \
        echo "Stowing $$pkg_name..."; \
        stow -v -R -t "$$HOME" "$$pkg_name"; \
    done

# Remove Stow symlinks
unstow:
    @echo "==> Unstowing all packages from $HOME..."
    @cd stow && for pkg in */; do \
        pkg_name=$${pkg%/}; \
        stow -v -D -t "$$HOME" "$$pkg_name"; \
    done

# Upgrade system packages and Flatpaks
update:
    sudo dnf upgrade -y
    @if command -v flatpak >/dev/null 2>&1; then \
        flatpak update -y; \
    fi

# Check Git and Stow status
status:
    @echo "==> Git status:"
    @git status -s

# Build and install Niri-Caelestia Shell QML modules
caelestia:
    @if [ ! -d "$$HOME/.config/quickshell/niri-caelestia-shell" ]; then \
        echo "==> Cloning Niri-Caelestia Shell repository..."; \
        git clone https://github.com/Ayushkr2003/niri-caelestia-shell.git "$$HOME/.config/quickshell/niri-caelestia-shell"; \
    fi
    @echo "==> Building and installing Niri-Caelestia Shell..."
    cd "$$HOME/.config/quickshell/niri-caelestia-shell" && \
        cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/ && \
        cmake --build build && \
        sudo cmake --install build

# Install or update Antigravity CLI (agy)
antigravity:
    @echo "==> Installing / Updating Antigravity CLI..."
    curl -fsSL https://antigravity.google/cli/install.sh | bash

# Install or update pi-coding-agent via npm
pi:
    @echo "==> Installing / Updating pi-coding-agent..."
    mkdir -p "$$HOME/.npm-global"
    npm config set prefix "$$HOME/.npm-global"
    npm install -g @earendil-works/pi-coding-agent
