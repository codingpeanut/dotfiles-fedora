#!/usr/bin/env bash
# ==============================================================================
# brightness-control.sh - Screen brightness controller with OSD notification
# Supports brightnessctl (laptops) and ddcutil (external monitors)
# ==============================================================================
set -euo pipefail

get_brightness() {
    local pct=""
    # 1. Try brightnessctl (laptop backlight or supported monitors)
    if command -v brightnessctl >/dev/null 2>&1; then
        local b_out
        b_out=$(brightnessctl -m 2>/dev/null || true)
        if [[ -n "$b_out" ]]; then
            pct=$(echo "$b_out" | head -n 1 | cut -d, -f4 | tr -d '%' || true)
        fi
    fi

    # 2. Try ddcutil for external monitors if brightnessctl didn't report
    if [[ -z "$pct" ]] && command -v ddcutil >/dev/null 2>&1; then
        local ddc_val
        ddc_val=$(ddcutil getvcp 10 2>/dev/null | grep -Po '(?<=current value = )\s*[0-9]+' | tr -d ' ' || true)
        if [[ -n "$ddc_val" ]]; then
            pct="$ddc_val"
        fi
    fi

    echo "${pct:-50}"
}

send_notification() {
    local pct="$1"
    local icon="display-brightness-symbolic"

    if (( pct <= 33 )); then
        icon="display-brightness-low-symbolic"
    elif (( pct <= 66 )); then
        icon="display-brightness-medium-symbolic"
    else
        icon="display-brightness-high-symbolic"
    fi

    if command -v notify-send >/dev/null 2>&1; then
        notify-send -u low \
            -h string:x-canonical-private-synchronous:brightness \
            -h string:synchronous:brightness \
            -h int:value:"$pct" \
            -i "$icon" \
            "螢幕亮度" "${pct}%"
    fi
}

adjust_brightness() {
    local mode="$1" # up, down, set
    local val="$2"  # step or exact value

    local handled=0

    # Try brightnessctl first
    if command -v brightnessctl >/dev/null 2>&1; then
        case "$mode" in
            up)
                brightnessctl set "+${val}%" >/dev/null 2>&1 && handled=1 || true
                ;;
            down)
                # Ensure minimum value of 1% so screen does not turn completely black
                brightnessctl --min-value=1 set "${val}%-" >/dev/null 2>&1 && handled=1 || true
                ;;
            set)
                brightnessctl set "${val}%" >/dev/null 2>&1 && handled=1 || true
                ;;
        esac
    fi

    # If brightnessctl didn't succeed or isn't available, try ddcutil
    if (( handled == 0 )) && command -v ddcutil >/dev/null 2>&1; then
        case "$mode" in
            up)
                ddcutil setvcp 10 + "$val" >/dev/null 2>&1 && handled=1 || true
                ;;
            down)
                ddcutil setvcp 10 - "$val" >/dev/null 2>&1 && handled=1 || true
                ;;
            set)
                ddcutil setvcp 10 "$val" >/dev/null 2>&1 && handled=1 || true
                ;;
        esac
    fi

    if (( handled == 0 )); then
        # Check if neither backend worked
        if ! command -v brightnessctl >/dev/null 2>&1 && ! command -v ddcutil >/dev/null 2>&1; then
            if command -v notify-send >/dev/null 2>&1; then
                notify-send -u critical "螢幕亮度錯誤" "未安裝 brightnessctl 或 ddcutil 工具"
            fi
            return 1
        fi
    fi

    local current_pct
    current_pct=$(get_brightness)
    send_notification "$current_pct"
}

is_touchpad_natural_scroll_enabled() {
    local config="${HOME}/.config/niri/config.kdl"
    if [[ ! -f "$config" ]]; then
        config="${HOME}/dev/dotfiles-fedora/stow/niri/.config/niri/config.kdl"
    fi
    if [[ -f "$config" ]]; then
        if awk '
            /touchpad[[:space:]]*\{/ { in_touchpad=1; next }
            in_touchpad && /\}/ { in_touchpad=0 }
            in_touchpad && /^[[:space:]]*natural-scroll([[:space:]]|$)/ { found=1 }
            END { exit(found ? 0 : 1) }
        ' "$config"; then
            return 0
        else
            return 1
        fi
    fi
    # Default fallback to true for Niri dotfiles
    return 0
}

action="${1:-notify}"
case "$action" in
    up|scroll-up)
        step="${2:-5}"
        adjust_brightness up "$step"
        ;;
    down|scroll-down)
        step="${2:-5}"
        adjust_brightness down "$step"
        ;;
    scroll-left)
        # Touchpad swipe direction adapts to natural-scroll:
        # Natural scroll ON:  physical swipe right -> emits GDK_SCROLL_LEFT -> increase (+step)
        # Natural scroll OFF: physical swipe left  -> emits GDK_SCROLL_LEFT -> decrease (-step)
        step="${2:-5}"
        if is_touchpad_natural_scroll_enabled; then
            adjust_brightness up "$step"
        else
            adjust_brightness down "$step"
        fi
        ;;
    scroll-right)
        # Natural scroll ON:  physical swipe left  -> emits GDK_SCROLL_RIGHT -> decrease (-step)
        # Natural scroll OFF: physical swipe right -> emits GDK_SCROLL_RIGHT -> increase (+step)
        step="${2:-5}"
        if is_touchpad_natural_scroll_enabled; then
            adjust_brightness down "$step"
        else
            adjust_brightness up "$step"
        fi
        ;;
    set)
        target="${2:-50}"
        # Clamp between 1 and 100
        (( target < 1 )) && target=1
        (( target > 100 )) && target=100
        adjust_brightness set "$target"
        ;;
    get)
        get_brightness
        ;;
    notify)
        current_pct=$(get_brightness)
        send_notification "$current_pct"
        ;;
    *)
        echo "Usage: $0 {up [step]|down [step]|scroll-left [step]|scroll-right [step]|set <1-100>|get|notify}"
        exit 1
        ;;
esac

