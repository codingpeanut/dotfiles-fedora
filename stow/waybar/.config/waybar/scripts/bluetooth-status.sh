#!/usr/bin/env bash
# ==============================================================================
# bluetooth-status.sh - Real-time Bluetooth JSON status for Waybar custom module
# ==============================================================================
set -u

# Check rfkill block status
if command -v rfkill >/dev/null 2>&1; then
    if rfkill list bluetooth 2>/dev/null | grep -qi "blocked: yes"; then
        echo '{"text":"󰂲","class":"off","tooltip":"藍芽已停用\n\n• 左鍵：開啟 Blueman 管理器\n• 中鍵：切換開關"}'
        exit 0
    fi
fi

# Check bluetoothctl presence
if ! command -v bluetoothctl >/dev/null 2>&1; then
    echo '{"text":"󰂲","class":"off","tooltip":"Bluetooth 未安裝\n\n• 請執行 just deps 安裝"}'
    exit 0
fi

# Check controller power status
powered=$(bluetoothctl show 2>/dev/null | grep -Po '(?<=Powered: )\w+' || echo "no")

if [[ "$powered" != "yes" ]]; then
    echo '{"text":"󰂲","class":"off","tooltip":"藍芽已關閉\n\n• 左鍵：開啟 Blueman 管理器\n• 中鍵：開啟藍芽"}'
    exit 0
fi

# Check connected devices
connected_name=""
while read -r _ mac name; do
    [[ -z "$mac" || -z "$name" ]] && continue
    if bluetoothctl info "$mac" 2>/dev/null | grep -q "Connected: yes"; then
        connected_name="$name"
        break
    fi
done < <(bluetoothctl devices 2>/dev/null || true)

if [[ -n "$connected_name" ]]; then
    clean_name=$(echo "$connected_name" | sed 's/"/\\"/g' | head -c 20)
    echo "{\"text\":\"󰂱 $clean_name\",\"class\":\"connected\",\"tooltip\":\"已連線裝置: $clean_name\n\n• 左鍵：開啟 Blueman 管理器\n• 中鍵：切換開關\"}"
else
    echo '{"text":"󰂯","class":"on","tooltip":"藍芽已開啟 (未連線裝置)\n\n• 左鍵：開啟 Blueman 管理器\n• 中鍵：切換開關"}'
fi
