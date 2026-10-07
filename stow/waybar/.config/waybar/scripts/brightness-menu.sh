#!/usr/bin/env bash
# ==============================================================================
# brightness-menu.sh - Interactive Screen Brightness selector (runs in desktop popup)
# Closable with Mod+Q (Niri), Esc, or q
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BRIGHTNESS_CONTROL="${SCRIPT_DIR}/brightness-control.sh"

make_bar() {
    local pct="$1"
    local total=20
    local filled=$(( pct * total / 100 ))
    (( filled > total )) && filled=$total
    (( filled < 0 )) && filled=0
    local empty=$(( total - filled ))
    printf "["
    printf "%0.s█" $(seq 1 $filled 2>/dev/null || true)
    printf "%0.s░" $(seq 1 $empty 2>/dev/null || true)
    printf "] %d%%" "$pct"
}

get_current_pct() {
    if [[ -x "$BRIGHTNESS_CONTROL" ]]; then
        "$BRIGHTNESS_CONTROL" get
    elif command -v brightness-control >/dev/null 2>&1; then
        brightness-control get
    else
        echo "50"
    fi
}

run_menu() {
    while true; do
        clear 2>/dev/null || true
        local current_pct
        current_pct=$(get_current_pct)

        local bar
        bar=$(make_bar "$current_pct")

        local header="󰃠 系統螢幕亮度調整 (Screen Brightness)"
        header+=$'\n'"目前亮度: $bar"
        header+=$'\n'"操作方式: [Enter] 套用調整  [Esc/q/Mod+Q] 關閉視窗"

        local options=()
        options+=("󰃠  亮度 +10% (快速調亮)")
        options+=("󰃟  亮度 +5%  (微調調亮)")
        options+=("󰃞  亮度 -5%  (微調調暗)")
        options+=("󰃞  亮度 -10% (快速調暗)")
        options+=("────────────────────────────────────────────────────────")
        options+=("󰃠  指定亮度：100% (最高亮度 / 戶外)")
        options+=("󰃠  指定亮度：80%  (明亮辦公)")
        options+=("󰃟  指定亮度：60%  (舒適預設)")
        options+=("󰃟  指定亮度：40%  (夜間閱讀)")
        options+=("󰃞  指定亮度：20%  (省電模式)")
        options+=("󰃞  指定亮度：10%  (暗室模式)")
        options+=("󰃞  指定亮度：5%   (最低背光)")
        options+=("────────────────────────────────────────────────────────")
        options+=("󰅖  關閉視窗 (Exit)")

        local choice
        choice=$(printf "%s\n" "${options[@]}" | fzf --ansi \
            --prompt="󰃠 亮度 > " \
            --header="$header" \
            --header-first \
            --layout=reverse \
            --border=rounded \
            --margin=1 \
            --no-info || true)

        [[ -z "$choice" || "$choice" =~ "關閉視窗" || "$choice" =~ "───" ]] && exit 0

        case "$choice" in
            *"+10%"*)
                "$BRIGHTNESS_CONTROL" up 10
                continue
                ;;
            *"+5%"*)
                "$BRIGHTNESS_CONTROL" up 5
                continue
                ;;
            *"-5%"*)
                "$BRIGHTNESS_CONTROL" down 5
                continue
                ;;
            *"-10%"*)
                "$BRIGHTNESS_CONTROL" down 10
                continue
                ;;
            *"100%"*)
                "$BRIGHTNESS_CONTROL" set 100
                continue
                ;;
            *"80%"*)
                "$BRIGHTNESS_CONTROL" set 80
                continue
                ;;
            *"60%"*)
                "$BRIGHTNESS_CONTROL" set 60
                continue
                ;;
            *"40%"*)
                "$BRIGHTNESS_CONTROL" set 40
                continue
                ;;
            *"20%"*)
                "$BRIGHTNESS_CONTROL" set 20
                continue
                ;;
            *"10%"*)
                "$BRIGHTNESS_CONTROL" set 10
                continue
                ;;
            *"5%"*)
                "$BRIGHTNESS_CONTROL" set 5
                continue
                ;;
        esac
    done
}

run_menu
