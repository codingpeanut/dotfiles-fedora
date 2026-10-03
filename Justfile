# Justfile - Declarative dotfiles & system manager
# Inspired by NixOS declarative workflow for Fedora

home := env("HOME")

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
    @echo "==> Stowing all packages into {{ home }}..."
    @if [ -f "{{ home }}/.bashrc" ] && [ ! -L "{{ home }}/.bashrc" ]; then \
        echo "Backing up existing regular ~/.bashrc to ~/.bashrc.bak..."; \
        mv "{{ home }}/.bashrc" "{{ home }}/.bashrc.bak"; \
    fi
    @if [ -f "{{ home }}/.vimrc" ] && [ ! -L "{{ home }}/.vimrc" ]; then \
        echo "Backing up existing regular ~/.vimrc to ~/.vimrc.bak..."; \
        mv "{{ home }}/.vimrc" "{{ home }}/.vimrc.bak"; \
    fi
    @if [ -f "{{ home }}/.config/niri/config.kdl" ] && [ ! -L "{{ home }}/.config/niri/config.kdl" ]; then \
        echo "Backing up existing regular ~/.config/niri/config.kdl to ~/.config/niri/config.kdl.bak..."; \
        mv "{{ home }}/.config/niri/config.kdl" "{{ home }}/.config/niri/config.kdl.bak"; \
    fi
    @cd stow && for pkg in */; do \
        pkg_name="${pkg%/}"; \
        echo "Stowing $pkg_name..."; \
        stow -v -R -t "{{ home }}" "$pkg_name"; \
    done

# Remove Stow symlinks
unstow:
    @echo "==> Unstowing all packages from {{ home }}..."
    @cd stow && for pkg in */; do \
        pkg_name="${pkg%/}"; \
        stow -v -D -t "{{ home }}" "$pkg_name"; \
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
    @rm -rf *HOME 2>/dev/null || true
    @if [ ! -d "{{ home }}/.config/quickshell/niri-caelestia-shell" ]; then \
        echo "==> Cloning Niri-Caelestia Shell repository..."; \
        git clone https://github.com/Ayushkr2003/niri-caelestia-shell.git "{{ home }}/.config/quickshell/niri-caelestia-shell"; \
    fi
    @echo "==> Ensuring required Qt6, Caelestia and libcava dependencies are installed..."
    sudo dnf copr enable -y celestelove/libcava || true
    sudo dnf install -y qt6-qtmultimedia-devel qt6-qtwayland-devel qt6-qtsvg-devel qt6-qtshadertools-devel libqalculate-devel aubio-devel pipewire-devel libddcutil-devel libcava-devel
    @echo "==> Building and installing Niri-Caelestia Shell..."
    cd "{{ home }}/.config/quickshell/niri-caelestia-shell" && \
        (git tag -f 1.1.1 >/dev/null 2>&1 || true) && \
        rm -rf build && \
        cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/ -DINSTALL_QMLDIR=usr/lib64/qt6/qml -DINSTALL_LIBDIR=usr/lib64/caelestia && \
        cmake --build build && \
        sudo cmake --install build && \
        (if [ -d "/usr/lib/qt6/qml/Caelestia" ] && [ ! -d "/usr/lib64/qt6/qml/Caelestia" ]; then \
            sudo cp -r /usr/lib/qt6/qml/Caelestia /usr/lib64/qt6/qml/; \
        fi)

# Install or update Antigravity CLI (agy)
antigravity:
    @echo "==> Installing / Updating Antigravity CLI..."
    curl -fsSL https://antigravity.google/cli/install.sh | bash

# Install or update pi-coding-agent via npm
pi:
    @echo "==> Installing / Updating pi-coding-agent..."
    mkdir -p "{{ home }}/.npm-global"
    npm config set prefix "{{ home }}/.npm-global"
    npm install -g @earendil-works/pi-coding-agent
