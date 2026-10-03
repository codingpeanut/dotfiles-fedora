#!/usr/bin/env bash
# ==============================================================================
# volume-menu.sh - Interactive Volume & Audio selector (runs in desktop_popup)
# Closable with Mod+Q (Niri), Esc, or q
# ==============================================================================
set -euo pipefail

notify() {
    local urgency="${1:-normal}"
    local title="$2"
    local msg="$3"
    if command -v notify-send >/dev/null 2>&1; then
        notify-send -u "$urgency" "$title" "$msg"
    fi
}

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

get_volume_info() {
    local vol_raw
    vol_raw=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null || true)
    if [[ -n "$vol_raw" ]]; then
        current_vol=$(echo "$vol_raw" | awk '{print int($2 * 100)}')
        if [[ "$vol_raw" =~ "MUTED" ]]; then
            is_muted=1
        else
            is_muted=0
        fi
    else
        # Fallback to pactl
        local pactl_raw
        pactl_raw=$(pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null || true)
        current_vol=$(echo "$pactl_raw" | grep -Po '[0-9]+(?=%)' | head -n 1 || echo "50")
        is_muted=$(pactl get-sink-mute @DEFAULT_SINK@ 2>/dev/null | grep -q "yes" && echo "1" || echo "0")
    fi
}

adjust_volume() {
    local delta="$1"
    if command -v wpctl >/dev/null 2>&1; then
        wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ "$delta"
    elif command -v pactl >/dev/null 2>&1; then
        pactl set-sink-volume @DEFAULT_SINK@ "$delta"
    fi
}

set_exact_volume() {
    local target="$1"
    if command -v wpctl >/dev/null 2>&1; then
        wpctl set-volume @DEFAULT_AUDIO_SINK@ "$target"
    elif command -v pactl >/dev/null 2>&1; then
        pactl set-sink-volume @DEFAULT_SINK@ "$target"
    fi
}

toggle_mute() {
    if command -v wpctl >/dev/null 2>&1; then
        wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
    elif command -v pactl >/dev/null 2>&1; then
        pactl set-sink-mute @DEFAULT_SINK@ toggle
    fi
}

switch_sink() {
    local sink_id="$1"
    if command -v wpctl >/dev/null 2>&1; then
        wpctl set-default "$sink_id"
        notify low "音訊設定" "已切換預設輸出設備 ID: $sink_id"
    fi
}

run_menu() {
    while true; do
        clear 2>/dev/null || true
        current_vol=50
        is_muted=0
        get_volume_info
        
        local bar
        bar=$(make_bar "$current_vol")
        
        local status_str="󰕾 音量正常"
        if (( is_muted == 1 )); then
            status_str="󰝟 已靜音"
        fi
        
        local header="󰕾 系統音量與輸出設備管理"
        header+=$'\n'"音量狀態: $bar  ($status_str)"
        header+=$'\n'"操作方式: [Enter] 調整/切換  [Esc/q/Mod+Q] 關閉視窗"
        
        local options=()
        options+=("󰕾  音量 +10% (提高音量)")
        options+=("󰕾  音量 +5%  (微調提高)")
        options+=("󰖀  音量 -5%  (微調降低)")
        options+=("󰖀  音量 -10% (降低音量)")
        if (( is_muted == 1 )); then
            options+=("󰕾  取消靜音 (Unmute)")
        else
            options+=("󰝟  切換靜音 (Mute)")
        fi
        options+=("────────────────────────────────────────────────────────")
        options+=("󰓃  指定音量：100%")
        options+=("󰓃  指定音量：75%")
        options+=("󰓃  指定音量：50%")
        options+=("󰓃  指定音量：25%")
        options+=("────────────────────────────────────────────────────────")
        
        # Query Audio Sinks
        declare -A sink_map=()
        if command -v wpctl >/dev/null 2>&1; then
            local sinks_raw
            sinks_raw=$(wpctl status 2>/dev/null || true)
            while IFS= read -r line; do
                [[ -z "$line" ]] && continue
                local is_active=""
                [[ "$line" =~ ^"󰄬" ]] && is_active="[使用中] "
                local sink_id
                sink_id=$(echo "$line" | grep -Po '(?<=\[ID:)[0-9]+(?=\])' || true)
                local sink_name
                sink_name=$(echo "$line" | sed 's/.*\] //')
                if [[ -n "$sink_id" && -n "$sink_name" ]]; then
                    local entry="󰋋  輸出設備: $is_active$sink_name"
                    options+=("$entry")
                    sink_map["$entry"]="$sink_id"
                fi
            done < <(echo "$sinks_raw" | awk '/Sinks:/{flag=1; next} /Sink endpoints:|Sources:/{flag=0} flag {
                if ($0 ~ /[0-9]+\./) {
                    active = ($0 ~ /\*/) ? "󰄬 " : "  "
                    gsub(/^[ │*]+/, "", $0)
                    id = $1
                    sub(/\./, "", id)
                    name = substr($0, index($0, ".") + 2)
                    sub(/\[vol:.*\]/, "", name)
                    gsub(/^[ \t]+|[ \t]+$/, "", name)
                    printf "%s[ID:%s] %s\n", active, id, name
                }
            }')
        fi
        
        options+=("────────────────────────────────────────────────────────")
        options+=("  開啟完整音訊混音器 (pavucontrol)")
        options+=("󰅖  關閉視窗 (Exit)")
        
        local choice
        choice=$(printf "%s\n" "${options[@]}" | fzf --ansi \
            --prompt="󰕾 音量 > " \
            --header="$header" \
            --header-first \
            --layout=reverse \
            --border=rounded \
            --margin=1 \
            --no-info || true)
            
        [[ -z "$choice" || "$choice" =~ "關閉視窗" || "$choice" =~ "───" ]] && exit 0
        
        case "$choice" in
            *"+10%"*)
                adjust_volume "10%+"
                continue
                ;;
            *"+5%"*)
                adjust_volume "5%+"
                continue
                ;;
            *"-5%"*)
                adjust_volume "5%-"
                continue
                ;;
            *"-10%"*)
                adjust_volume "10%-"
                continue
                ;;
            *"靜音"*)
                toggle_mute
                continue
                ;;
            *"100%"*)
                set_exact_volume "1.0"
                continue
                ;;
            *"75%"*)
                set_exact_volume "0.75"
                continue
                ;;
            *"50%"*)
                set_exact_volume "0.50"
                continue
                ;;
            *"25%"*)
                set_exact_volume "0.25"
                continue
                ;;
            *"混音器"*)
                pavucontrol &
                exit 0
                ;;
            *"輸出設備:"*)
                local sid="${sink_map["$choice"]:-}"
                if [[ -n "$sid" ]]; then
                    switch_sink "$sid"
                fi
                continue
                ;;
        esac
    done
}

run_menu
