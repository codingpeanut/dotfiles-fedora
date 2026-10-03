#!/usr/bin/env bash
# ==============================================================================
# power-menu.sh - Wayland session & power menu launcher (wlogout / fuzzel fallback)
# ==============================================================================
set -euo pipefail

# 1. Prefer wlogout (mature graphical Wayland logout menu)
if command -v wlogout >/dev/null 2>&1; then
    exec wlogout -b 5 -c 20 -r 20 "$@"
fi

# 2. Fallback to fuzzel if wlogout is not installed yet
if command -v fuzzel >/dev/null 2>&1; then
    options=(
        "󰌾  鎖定螢幕 (Lock Screen)"
        "󰤄  睡眠暫停 (Suspend)"
        "󰗽  登出桌面 (Log Out)"
        "  重新啟動 (Reboot)"
        "󰐥  關閉電腦 (Power Off)"
    )

    chosen=$(printf "%s\n" "${options[@]}" | fuzzel -d -p "⏻ 電源選單: " -w 28 -l 6 || true)
    [[ -z "$chosen" ]] && exit 0

    case "$chosen" in
        *"鎖定螢幕"*)
            command -v swaylock >/dev/null 2>&1 && swaylock -f
            ;;
        *"睡眠暫停"*)
            systemctl suspend
            ;;
        *"登出桌面"*)
            niri msg action quit --skip-confirmation 2>/dev/null || pkill niri || true
            ;;
        *"重新啟動"*)
            systemctl reboot
            ;;
        *"關閉電腦"*)
            systemctl poweroff
            ;;
    esac
    exit 0
fi

if command -v notify-send >/dev/null 2>&1; then
    notify-send -u critical "Power Menu" "找不到 wlogout，請執行 'just deps' 安裝"
fi
