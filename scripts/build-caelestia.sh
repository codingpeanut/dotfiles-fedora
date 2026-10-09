#!/usr/bin/env bash
# ==============================================================================
# build-caelestia.sh - Build and install Niri-Caelestia Shell QML modules
# ==============================================================================
set -euo pipefail

TARGET_DIR="${HOME}/.config/quickshell/niri-caelestia-shell"

rm -rf *HOME 2>/dev/null || true

if [ ! -d "$TARGET_DIR" ]; then
    echo "==> Cloning Niri-Caelestia Shell repository..."
    git clone https://github.com/Ayushkr2003/niri-caelestia-shell.git "$TARGET_DIR"
fi

echo "==> Ensuring required Qt6, Caelestia and libcava dependencies are installed..."
sudo dnf copr enable -y celestelove/libcava || true
sudo dnf install -y qt6-qtmultimedia-devel qt6-qtwayland-devel qt6-qtsvg-devel qt6-qtshadertools-devel qt6-qt5compat qt6-qt5compat-devel libqalculate-devel aubio-devel pipewire-devel libddcutil-devel libcava-devel

echo "==> Building and installing Niri-Caelestia Shell..."
cd "$TARGET_DIR"
(git tag -f 1.1.1 >/dev/null 2>&1 || true)
rm -rf build
cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/ -DINSTALL_QMLDIR=usr/lib64/qt6/qml -DINSTALL_LIBDIR=usr/lib64/caelestia
cmake --build build
sudo cmake --install build

if [ -d "/usr/lib/qt6/qml/Caelestia" ] && [ ! -d "/usr/lib64/qt6/qml/Caelestia" ]; then
    sudo cp -r /usr/lib/qt6/qml/Caelestia /usr/lib64/qt6/qml/
fi

echo "==> Niri-Caelestia Shell built and installed successfully!"
