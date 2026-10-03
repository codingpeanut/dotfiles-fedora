#!/usr/bin/env bash
# ==============================================================================
# power-menu.sh - Wayland session & power menu powered by fuzzel
# ==============================================================================
set -euo pipefail

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
        if command -v swaylock >/dev/null 2>&1; then
            swaylock -f
        fi
        ;;
    *"睡眠暫停"*)
        systemctl suspend
        ;;
    *"登出桌面"*)
        confirm=$(printf "󰗽  確認登出\n  取消\n" | fuzzel -d -p "確定登出工作階段？ " -w 24 -l 2 || true)
        if [[ "$confirm" =~ "確認登出" ]]; then
            niri msg action quit --skip-confirmation 2>/dev/null || pkill niri || true
        fi
        ;;
    *"重新啟動"*)
        confirm=$(printf "  確認重開機\n  取消\n" | fuzzel -d -p "確定重新啟動電腦？ " -w 24 -l 2 || true)
        if [[ "$confirm" =~ "確認重開機" ]]; then
            systemctl reboot
        fi
        ;;
    *"關閉電腦"*)
        confirm=$(printf "󰐥  確認關機\n  取消\n" | fuzzel -d -p "確定關閉電腦？ " -w 24 -l 2 || true)
        if [[ "$confirm" =~ "確認關機" ]]; then
            systemctl poweroff
        fi
        ;;
esac
