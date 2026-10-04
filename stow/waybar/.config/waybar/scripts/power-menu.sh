#!/usr/bin/env bash
# ==============================================================================
# power-menu.sh - Wayland session & power menu launcher (wlogout / fuzzel fallback)
# ==============================================================================
set -euo pipefail

# 1. Prefer wlogout (mature graphical Wayland logout menu)
if command -v wlogout >/dev/null 2>&1; then
    # Calculate screen margins dynamically so the buttons are centered and square (1:1 aspect ratio)
    read -r m_tb m_lr col_gap < <(python3 -c "
import json, subprocess

w, h = 1920, 1080
try:
    p = subprocess.run(['niri', 'msg', '-j', 'outputs'], capture_output=True, text=True, timeout=0.8)
    if p.returncode == 0 and p.stdout.strip():
        d = json.loads(p.stdout)
        outs = d if isinstance(d, list) else list(d.values())
        for o in outs:
            if 'logical' in o and isinstance(o['logical'], dict):
                w, h = int(o['logical']['width']), int(o['logical']['height'])
                break
            elif 'logical_size' in o and isinstance(o['logical_size'], dict):
                w, h = int(o['logical_size']['width']), int(o['logical_size']['height'])
                break
            elif 'current_mode' in o and isinstance(o['current_mode'], dict):
                s = float(o.get('scale', 1.0)) or 1.0
                w, h = int(o['current_mode']['width'] / s), int(o['current_mode']['height'] / s)
                break
except Exception:
    pass

num_btns = 5
gap = 18
btn_w = 104
btn_h = 116
total_w = num_btns * btn_w + (num_btns - 1) * gap
total_h = btn_h
tb = max(20, (h - total_h) // 2)
lr = max(20, (w - total_w) // 2)
print(f'{tb} {lr} {gap}')
" 2>/dev/null || echo "482 664 18")

    exec wlogout -b 5 -c "$col_gap" -r 0 -T "$m_tb" -B "$m_tb" -L "$m_lr" -R "$m_lr" "$@"
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
