#!/usr/bin/env bash
# bootstrap.sh - Initialize a fresh Fedora workstation to declarative dotfiles
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "=================================================="
echo " Fedora Declarative Dotfiles Bootstrap"
echo "=================================================="

# Check if dnf exists
if ! command -v dnf >/dev/null 2>&1; then
    echo "Error: 'dnf' command not found. This script is designed for Fedora Linux." >&2
    exit 1
fi

echo "==> [1/3] Installing core bootstrap dependencies (git, ansible, just, stow)..."
sudo dnf install -y git ansible just stow

cd "$DOTFILES_DIR"

echo "==> [2/3] Setting up local variables template..."
if [ ! -f "ansible/vars/local.yml" ] && [ -f "ansible/vars/local.yml.example" ]; then
    cp ansible/vars/local.yml.example ansible/vars/local.yml
    echo "Created ansible/vars/local.yml from template. You can customize it anytime."
fi

echo "==> [3/3] Running initial full setup via Just / Ansible..."
if command -v just >/dev/null 2>&1; then
    just apply
else
    ansible-playbook -i ansible/inventory.ini ansible/playbook.yml --ask-become-pass
fi

echo "=================================================="
echo " Bootstrap complete! Welcome to your Niri desktop."
echo "=================================================="
