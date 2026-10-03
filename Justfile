# Justfile - Declarative dotfiles & system manager
# Inspired by NixOS declarative workflow for Fedora

default:
    @just --list

# Apply full configuration (system packages + dotfiles + user services)
apply:
    ansible-playbook -i ansible/inventory.ini ansible/playbook.yml --ask-become-pass

# Sync and apply dotfiles symlinks via GNU Stow
dotfiles:
    ansible-playbook -i ansible/inventory.ini ansible/playbook.yml --tags dotfiles

# Run only system-level configuration (DNF packages, COPR repos, systemd services)
system:
    ansible-playbook -i ansible/inventory.ini ansible/playbook.yml --tags system --ask-become-pass

# Run only user-level configuration (dotfiles, flatpaks, user services)
user:
    ansible-playbook -i ansible/inventory.ini ansible/playbook.yml --tags user

# Fast direct Stow re-link for all packages without running Ansible
stow:
    @echo "==> Stowing all packages into $HOME..."
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
