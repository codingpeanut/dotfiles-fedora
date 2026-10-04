#!/usr/bin/env bash
# ==============================================================================
# fcitx5-status.sh - Real-time Fcitx5 IME status for Waybar custom module
# ==============================================================================
set -u

if ! command -v fcitx5-remote >/dev/null 2>&1; then
    echo '{"text":"󰌌 --","tooltip":"fcitx5-remote 未安裝"}'
    exit 0
fi

# fcitx5-remote return codes:
# 0: fcitx5 not running
# 1: inactive (English/Direct input)
# 2: active (Chinese/Chewing/IME input)
state=$(fcitx5-remote 2>/dev/null || echo 0)

case "$state" in
    2)
        echo '{"text":"󰌌 中","class":"active","tooltip":"輸入法狀態：中文 (Chewing)\n\n• 左鍵：切換英/中\n• 右鍵：開啟輸入法設定"}'
        ;;
    1)
        echo '{"text":"󰌌 EN","class":"inactive","tooltip":"輸入法狀態：英文 (Direct)\n\n• 左鍵：切換英/中\n• 右鍵：開啟輸入法設定"}'
        ;;
    *)
        echo '{"text":"󰌌 關","class":"off","tooltip":"fcitx5 尚未啟動\n\n• 左鍵：啟動 fcitx5"}'
        ;;
esac
