#!/usr/bin/env bash
# ==============================================================================
# blueman-menu.sh - Native graphical menu for Blueman right-click actions
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

# Check Bluetooth power status
powered=$(bluetoothctl show 2>/dev/null | grep -Po '(?<=Powered: )\w+' || echo "no")

menu_items=()

# 1. Power toggle
if [[ "$powered" == "yes" ]]; then
    menu_items+=("󰂲  關閉藍芽 (Power Off)")
    menu_items+=("󰂱  設為可被探索 (Make Discoverable)")
else
    menu_items+=("󰂯  開啟藍芽 (Power On)")
fi

# 2. Core Blueman utilities
menu_items+=("  開啟裝置管理員 (blueman-manager)")
menu_items+=("  介面卡設定... (blueman-adapters)")
menu_items+=("󰇮  本地服務設定... (blueman-services)")
menu_items+=("  傳送檔案至裝置... (blueman-sendto)")

# 3. Paired devices (Quick connect / disconnect)
declare -A dev_mac=()
declare -A dev_conn=()

if [[ "$powered" == "yes" ]]; then
    paired_raw=$(bluetoothctl devices 2>/dev/null || true)
    if [[ -n "$paired_raw" ]]; then
        menu_items+=("──────────────────────────────────────────")
        while read -r _ mac name; do
            [[ -z "$mac" || -z "$name" ]] && continue
            info=$(bluetoothctl info "$mac" 2>/dev/null || true)
            is_connected="no"
            if echo "$info" | grep -q "Connected: yes"; then
                is_connected="yes"
            fi
            
            if [[ "$is_connected" == "yes" ]]; then
                display="󰂱  [已連線] $name (中斷連線)"
            else
                display="󰂯  [已配對] $name (連線裝置)"
            fi
            menu_items+=("$display")
            dev_mac["$display"]="$mac"
            dev_conn["$display"]="$is_connected"
        done <<< "$paired_raw"
    fi
fi

# Prompt via Fuzzel
chosen=$(printf "%s\n" "${menu_items[@]}" | fuzzel -d -p "󰂯 Blueman: " -w 38 -l 10 || true)

[[ -z "$chosen" || "$chosen" =~ ─── ]] && exit 0

case "$chosen" in
    *"關閉藍芽"*)
        bluetoothctl power off
        notify normal "藍芽" "藍芽已關閉"
        exit 0
        ;;
    *"開啟藍芽"*)
        bluetoothctl power on
        notify low "藍芽" "藍芽已開啟"
        exit 0
        ;;
    *"設為可被探索"*)
        bluetoothctl discoverable on
        notify normal "藍芽" "藍芽已設為可被搜尋 (Discoverable)"
        exit 0
        ;;
    *"裝置管理員"*)
        blueman-manager &
        exit 0
        ;;
    *"介面卡設定"*)
        blueman-adapters &
        exit 0
        ;;
    *"本地服務設定"*)
        blueman-services &
        exit 0
        ;;
    *"傳送檔案至裝置"*)
        blueman-sendto &
        exit 0
        ;;
esac

# Handle quick device connect / disconnect
target_mac="${dev_mac["$chosen"]:-}"
target_conn="${dev_conn["$chosen"]:-}"

if [[ -n "$target_mac" ]]; then
    if [[ "$target_conn" == "yes" ]]; then
        bluetoothctl disconnect "$target_mac" 2>/dev/null || true
        notify normal "藍芽" "已中斷裝置連線"
    else
        notify low "藍芽" "正在連線至裝置..."
        if bluetoothctl connect "$target_mac" 2>/dev/null; then
            notify normal "藍芽" "連線成功！"
        else
            notify critical "藍芽" "連線失敗，請確認裝置已開機"
        fi
    fi
fi
