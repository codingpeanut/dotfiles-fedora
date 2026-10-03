#!/usr/bin/env bash
# ==============================================================================
# wifi-menu.sh - Modern Wayland Wi-Fi selector powered by nmcli & fuzzel
# ==============================================================================
set -euo pipefail

# Check dependencies
for cmd in nmcli fuzzel; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        if command -v notify-send >/dev/null 2>&1; then
            notify-send -u critical "Wi-Fi Menu" "未找到必要工具: $cmd"
        fi
        echo "Missing required dependency: $cmd" >&2
        exit 1
    fi
done

notify() {
    local urgency="${1:-normal}"
    local title="$2"
    local msg="$3"
    if command -v notify-send >/dev/null 2>&1; then
        notify-send -u "$urgency" "$title" "$msg"
    fi
}

# Check Wi-Fi radio status
wifi_status=$(nmcli -fields WIFI g 2>/dev/null | tail -n 1 | tr -d '[:space:]')

if [[ "$wifi_status" =~ ^disabled ]]; then
    chosen=$(printf "󰖩  開啟 Wi-Fi (Turn Wi-Fi On)\n  網路連線設定 (GUI)\n" | fuzzel -d -p "󰖩 Wi-Fi: " -w 35 -l 3 || true)
    case "$chosen" in
        *"開啟 Wi-Fi"*)
            nmcli radio wifi on
            notify low "Wi-Fi" "Wi-Fi 已開啟，正在搜尋附近網路..."
            sleep 1.5
            exec "$0"
            ;;
        *"網路連線設定"*)
            nm-connection-editor &
            ;;
    esac
    exit 0
fi

# Get current active Wi-Fi connection name (if any)
active_conn=$(nmcli -t -f TYPE,NAME connection show --active 2>/dev/null | grep '^802-11-wireless:' | cut -d: -f2 || true)

# Scan for available Wi-Fi networks using nmcli
raw_list=$(nmcli --terse --fields IN-USE,SSID,SIGNAL,SECURITY device wifi list 2>/dev/null || true)

declare -A ssid_map
declare -A sec_map
declare -A sig_map
declare -A in_use_map

menu_entries=()

# Process each detected AP
while IFS=':' read -r in_use ssid signal security; do
    # Skip hidden/blank SSIDs
    [[ -z "$ssid" || "$ssid" == "--" ]] && continue
    
    # Store maximum signal if SSID seen multiple times
    current_best="${sig_map["$ssid"]:-0}"
    if (( signal >= current_best )); then
        sig_map["$ssid"]="$signal"
        sec_map["$ssid"]="$security"
        [[ "$in_use" == "*" ]] && in_use_map["$ssid"]="1"
    fi
done <<< "$raw_list"

# Sort SSIDs by signal strength descending
sorted_ssids=$(for s in "${!sig_map[@]}"; do
    printf "%03d\t%s\n" "${sig_map["$s"]}" "$s"
done | sort -rn | cut -f2-)

# Build display list
while IFS= read -r s; do
    [[ -z "$s" ]] && continue
    sig="${sig_map["$s"]}"
    sec="${sec_map["$s"]}"
    
    # Signal Icon
    if (( sig >= 75 )); then
        icon="󰤨"
    elif (( sig >= 50 )); then
        icon="󰤥"
    elif (( sig >= 25 )); then
        icon="󰤢"
    else
        icon="󰤟"
    fi
    
    # Lock Icon
    lock=""
    if [[ -n "$sec" && "$sec" != "--" ]]; then
        lock=" "
    fi
    
    # In-use status
    if [[ -n "${in_use_map["$s"]:-}" || "$s" == "$active_conn" ]]; then
        display="󰄬 $icon  $s  ($sig%) $lock[已連線]"
    else
        display="   $icon  $s  ($sig%) $lock"
    fi
    
    menu_entries+=("$display")
    ssid_map["$display"]="$s"
done <<< "$sorted_ssids"

# Action items
actions=()
if [[ -n "$active_conn" ]]; then
    actions+=("󰌙  中斷目前連線 ($active_conn)")
fi
actions+=("  重新搜尋網路 (Rescan)")
actions+=("󰖪  關閉 Wi-Fi (Turn Off)")
actions+=("  開啟詳細設定 (nm-connection-editor)")

# Combine actions + network entries
full_menu=$(printf "%s\n" "${actions[@]}" "${menu_entries[@]}")

# Prompt user via fuzzel dmenu
selected=$(printf "%s\n" "$full_menu" | fuzzel -d -p "󰖩 Wi-Fi: " -w 45 -l 14 || true)

[[ -z "$selected" ]] && exit 0

case "$selected" in
    *"關閉 Wi-Fi"*)
        nmcli radio wifi off
        notify normal "Wi-Fi" "Wi-Fi 已關閉"
        exit 0
        ;;
    *"重新搜尋網路"*)
        notify low "Wi-Fi" "正在重新搜尋周遭 Wi-Fi..."
        nmcli device wifi rescan 2>/dev/null || true
        sleep 1.2
        exec "$0"
        ;;
    *"開啟詳細設定"*)
        nm-connection-editor &
        exit 0
        ;;
    *"中斷目前連線"*)
        nmcli connection down "$active_conn" 2>/dev/null || true
        notify normal "Wi-Fi" "已中斷連線：$active_conn"
        exit 0
        ;;
esac

# User chose a specific Wi-Fi SSID
target_ssid="${ssid_map["$selected"]:-}"
[[ -z "$target_ssid" ]] && exit 0

# Check if already connected
if [[ "$target_ssid" == "$active_conn" ]]; then
    notify low "Wi-Fi" "目前已連線至 $target_ssid"
    exit 0
fi

# Check if connection profile already saved
saved_conn=$(nmcli -t -f NAME connection show 2>/dev/null | grep -Fx "$target_ssid" || true)

if [[ -n "$saved_conn" ]]; then
    notify low "Wi-Fi" "正在連線至已知網路 $target_ssid..."
    if nmcli connection up "$target_ssid" 2>/dev/null; then
        notify normal "Wi-Fi" "成功連線至 $target_ssid"
    else
        notify critical "Wi-Fi" "連線至 $target_ssid 失敗"
    fi
    exit 0
fi

# If not saved, check if password needed
target_sec="${sec_map["$target_ssid"]:-}"
if [[ -n "$target_sec" && "$target_sec" != "--" ]]; then
    # Prompt password
    pass=$(fuzzel -d --password -p "請輸入 $target_ssid 的密碼: " -w 35 -l 0 || true)
    [[ -z "$pass" ]] && exit 0
    
    notify low "Wi-Fi" "正在連線至 $target_ssid..."
    if nmcli device wifi connect "$target_ssid" password "$pass" 2>/dev/null; then
        notify normal "Wi-Fi" "成功連線至 $target_ssid"
    else
        notify critical "Wi-Fi" "連線失敗，請檢查密碼"
    fi
else
    # Open network (no password)
    notify low "Wi-Fi" "正在連線至開放網路 $target_ssid..."
    if nmcli device wifi connect "$target_ssid" 2>/dev/null; then
        notify normal "Wi-Fi" "成功連線至 $target_ssid"
    else
        notify critical "Wi-Fi" "連線至 $target_ssid 失敗"
    fi
fi
