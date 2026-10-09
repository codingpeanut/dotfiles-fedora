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
    @if [ ! -L "{{ home }}/.config/niri" ] && [ -f "{{ home }}/.config/niri/config.kdl" ] && [ ! -L "{{ home }}/.config/niri/config.kdl" ]; then \
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

# One-command sync: pull latest, auto-stow, and reload desktop bars
pull:
    @echo "==> Pulling latest dotfiles from remote..."
    @git pull --rebase --autostash || (echo "==> Auto-resolving conflict with origin/main..." && git reset --hard origin/main)
    @just stow
    @just reload
    @echo "==> All dotfiles synced, stowed, and reloaded successfully!"

# Reload running desktop components (Niri, Waybar, Mako, Fcitx5)
reload:
    @echo "==> Reloading Niri compositor configuration..."
    @(niri msg action reload-config 2>/dev/null || true)
    @echo "==> Restarting Waybar and Mako..."
    @(killall blueman-applet 2>/dev/null || true)
    @(killall waybar 2>/dev/null || true)
    @sleep 0.3
    @(nohup waybar >/dev/null 2>&1 &)
    @(killall mako 2>/dev/null || true)
    @(nohup mako >/dev/null 2>&1 &)
    @echo "==> Reloading Fcitx5 configuration..."
    @(fcitx5-remote -r 2>/dev/null || true)
    @echo "==> Reloading Idle Manager (swayidle)..."
    @(idle-manager reload 2>/dev/null || true)

# Install required desktop dependencies for Waybar buttons and utilities
deps:
    @echo "==> Installing desktop dependencies (Waybar, popups, audio, network, monitor, bluetooth, wlogout)..."
    sudo dnf install -y btop NetworkManager-tui nm-connection-editor network-manager-applet gnome-calendar gnome-control-center pavucontrol waybar mako fuzzel kitty swaylock swayidle brightnessctl ddcutil playerctl wl-clipboard cliphist libnotify fzf blueman bluez bluez-tools python3-dbus python3-gobject gtk3 gtk4 wlogout fcitx5 fcitx5-chinese-addons fcitx5-chewing fcitx5-configtool fcitx5-gtk3 fcitx5-gtk4 fcitx5-qt5 fcitx5-qt6 imsettings
    sudo systemctl enable --now bluetooth || true
    @if ! command -v powerprofilesctl >/dev/null 2>&1; then \
        echo "==> Ensuring power profiles provider is installed (tuned-ppd / power-profiles-daemon)..."; \
        sudo dnf install -y tuned-ppd 2>/dev/null || sudo dnf install -y power-profiles-daemon 2>/dev/null || true; \
    fi
    @if command -v imsettings-switch >/dev/null 2>&1; then \
        echo "==> Setting default input method framework to fcitx5..."; \
        imsettings-switch fcitx5 2>/dev/null || true; \
    fi
    @if ! command -v nmgui >/dev/null 2>&1 && [ ! -f "{{ home }}/.local/bin/nmgui" ]; then \
        echo "==> Installing nmgui (GTK4 NetworkManager GUI) to {{ home }}/.local/bin/nmgui..."; \
        mkdir -p "{{ home }}/.local/bin"; \
        curl -sL https://github.com/s-adi-dev/nmgui/releases/download/v1.0.0/main.bin -o "{{ home }}/.local/bin/nmgui"; \
        chmod +x "{{ home }}/.local/bin/nmgui"; \
    fi

# One-stop command to fix everything: pull, install dependencies, stow, restart bars, and verify
fix:
    @echo "==> Pulling latest changes from Git..."
    @git pull --rebase --autostash || git reset --hard origin/main
    @just deps
    @just stow
    @just reload
    @just check
    @echo "==> All dotfiles, dependencies, and Waybar/Mako have been fixed and reloaded!"

# One-command commit & push local changes to GitHub
push msg="chore: update dotfiles":
    @git add -A
    @git commit -m "{{ msg }}" || true
    @git push origin main
    @echo "==> Changes pushed to GitHub successfully."

# Quick-edit specific configuration files
edit app="niri":
    @case "{{ app }}" in \
        niri) ${EDITOR:-nvim} stow/niri/.config/niri/config.kdl ;; \
        waybar) ${EDITOR:-nvim} stow/waybar/.config/waybar/config.jsonc && pkill -SIGUSR2 waybar 2>/dev/null || true ;; \
        kitty) ${EDITOR:-nvim} stow/kitty/.config/kitty/kitty.conf ;; \
        fuzzel) ${EDITOR:-nvim} stow/fuzzel/.config/fuzzel/fuzzel.ini ;; \
        wlogout) ${EDITOR:-nvim} stow/wlogout/.config/wlogout/layout ;; \
        fcitx5) ${EDITOR:-nvim} stow/fcitx5/.config/fcitx5/config && (fcitx5-remote -r 2>/dev/null || true) ;; \
        *) echo "Unknown app: {{ app }}. Available: niri, waybar, kitty, fuzzel, wlogout, fcitx5" ;; \
    esac

# Check all desktop, CLI, and Wayland dependencies
check:
    @echo "==> Checking system dependencies..."
    @for cmd in niri waybar kitty fuzzel mako btop nmtui nm-connection-editor nm-applet gnome-control-center nmgui pavucontrol gnome-calendar swaylock swayidle brightnessctl ddcutil playerctl wl-paste cliphist fcitx5 notify-send fzf blueman-manager wlogout powerprofilesctl; do \
        if command -v "$cmd" >/dev/null 2>&1; then \
            printf "  [✓] %-24s found (%s)\n" "$cmd" "$(command -v "$cmd")"; \
        else \
            printf "  [✗] %-24s NOT FOUND\n" "$cmd"; \
        fi \
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
