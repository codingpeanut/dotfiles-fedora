#!/usr/bin/env bash
# ==============================================================================
# power-profile.sh - Power & energy profile manager with OSD notifications
# Cycled via Waybar battery module, powered by powerprofilesctl
# ==============================================================================
set -euo pipefail

# 1. Check if powerprofilesctl is available
if ! command -v powerprofilesctl >/dev/null 2>&1; then
    if command -v notify-send >/dev/null 2>&1; then
        notify-send -u normal -a "power-profile" \
            "能源管理模式" "找不到 powerprofilesctl，請執行 'just deps' 安裝 power-profiles-daemon"
    fi
    exit 1
fi

get_current_profile() {
    powerprofilesctl get 2>/dev/null || echo "balanced"
}

get_available_profiles() {
    local list
    list=$(powerprofilesctl list 2>/dev/null | grep -E '^[ *]*[a-zA-Z0-9_-]+:' | awk -F: '{print $1}' | tr -d ' *' || true)
    if [[ -n "$list" ]]; then
        echo "$list"
    else
        printf "power-saver\nbalanced\nperformance\n"
    fi
}

send_notification() {
    local profile="$1"
    local title=""
    local body=""
    local icon="battery-charging-symbolic"

    case "$profile" in
        performance)
            title=" 能源模式：高效能 (Performance)"
            body="釋放 CPU/GPU 完整效能，適合高負載任務與遊戲"
            icon="power-profile-performance-symbolic"
            ;;
        power-saver)
            title=" 能源模式：省電模式 (Power Saver)"
            body="限制系統能耗與頻率，大幅延長電池續航時間"
            icon="power-profile-power-saver-symbolic"
            ;;
        balanced|*)
            title="󰾅 能源模式：平衡模式 (Balanced)"
            body="自動在運算效能與功耗散熱間取得最佳平衡"
            icon="power-profile-balanced-symbolic"
            ;;
    esac

    if command -v notify-send >/dev/null 2>&1; then
        notify-send -u low \
            -a "power-profile" \
            -h string:x-canonical-private-synchronous:energy-profile \
            -h string:synchronous:energy-profile \
            -i "$icon" \
            "$title" "$body"
    fi
}

cycle_profile() {
    local current
    current=$(get_current_profile)

    mapfile -t available < <(get_available_profiles)
    local num_profiles="${#available[@]}"

    if (( num_profiles == 0 )); then
        available=("power-saver" "balanced" "performance")
        num_profiles=3
    fi

    # Standard cycle order: balanced -> performance -> power-saver -> balanced
    local next="balanced"

    case "$current" in
        balanced)
            if [[ " ${available[*]} " =~ " performance " ]]; then
                next="performance"
            else
                next="power-saver"
            fi
            ;;
        performance)
            if [[ " ${available[*]} " =~ " power-saver " ]]; then
                next="power-saver"
            else
                next="balanced"
            fi
            ;;
        power-saver)
            next="balanced"
            ;;
        *)
            next="balanced"
            ;;
    esac

    powerprofilesctl set "$next" 2>/dev/null || true
    send_notification "$next"
}

action="${1:-cycle}"
case "$action" in
    cycle)
        cycle_profile
        ;;
    get)
        get_current_profile
        ;;
    set)
        target="${2:-balanced}"
        powerprofilesctl set "$target" 2>/dev/null || true
        send_notification "$target"
        ;;
    notify)
        send_notification "$(get_current_profile)"
        ;;
    *)
        echo "Usage: $0 {cycle|get|set <profile>|notify}"
        exit 1
        ;;
esac
