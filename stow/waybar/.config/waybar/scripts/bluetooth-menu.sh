#!/usr/bin/env bash
# ==============================================================================
# bluetooth-menu.sh - Interactive Bluetooth manager (runs in desktop_popup)
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

run_menu() {
    while true; do
        clear 2>/dev/null || true
        
        # Check power status
        local powered
        powered=$(bluetoothctl show 2>/dev/null | grep -Po '(?<=Powered: )\w+' || echo "no")
        
        local header="󰂯 藍芽裝置管理"
        if [[ "$powered" != "yes" ]]; then
            header+=$'\n狀態: [藍芽已關閉] | 操作: [Enter] 選擇  [Esc/q/Mod+Q] 關閉視窗'
            local opts=("󰂯  開啟藍芽 (Power On)" "  開啟進階藍芽管理員 (blueman-manager)" "󰅖  關閉視窗 (Exit)")
            local choice
            choice=$(printf "%s\n" "${opts[@]}" | fzf --ansi --prompt="󰂯 藍芽 > " --header="$header" --layout=reverse --border=rounded --no-info || true)
            case "$choice" in
                *"開啟藍芽"*)
                    bluetoothctl power on
                    notify low "藍芽" "藍芽已開啟"
                    sleep 1
                    continue
                    ;;
                *"進階藍芽管理員"*)
                    blueman-manager &
                    exit 0
                    ;;
                *)
                    exit 0
                    ;;
            esac
        fi
        
        header+=$'\n狀態: [藍芽已開啟] | 操作: [Enter] 連線/中斷  [Esc/q/Mod+Q] 關閉視窗'
        
        # Query Paired Devices
        declare -A dev_mac=()
        declare -A dev_conn=()
        
        local paired_raw
        paired_raw=$(bluetoothctl devices 2>/dev/null || true)
        
        local device_entries=()
        while read -r _ mac name; do
            [[ -z "$mac" || -z "$name" ]] && continue
            
            # Check connection status
            local info
            info=$(bluetoothctl info "$mac" 2>/dev/null || true)
            local is_connected="no"
            local battery=""
            if echo "$info" | grep -q "Connected: yes"; then
                is_connected="yes"
            fi
            if echo "$info" | grep -q "Battery Percentage:"; then
                local bat_pct
                bat_pct=$(echo "$info" | grep -Po '(?<=Battery Percentage: 0x[0-9a-fA-F]{2} \()[0-9]+(?=\))' || true)
                [[ -n "$bat_pct" ]] && battery=" [電量: $bat_pct%]"
            fi
            
            local display
            if [[ "$is_connected" == "yes" ]]; then
                display=$(printf "\033[1;32m󰂱  [已連線]  %-26s%s (點擊中斷)\033[0m" "$name" "$battery")
            else
                display=$(printf "󰂯  [已配對]  %-26s (點擊連線)" "$name")
            fi
            
            device_entries+=("$display")
            local clean_display
            clean_display=$(echo -e "$display" | sed 's/\x1b\[[0-9;]*m//g')
            dev_mac["$clean_display"]="$mac"
            dev_conn["$clean_display"]="$is_connected"
        done <<< "$paired_raw"
        
        local actions=()
        actions+=("  搜尋附近新裝置 (Scan Devices)")
        actions+=("󰂲  關閉藍芽 (Power Off)")
        actions+=("  開啟進階藍芽管理員 (blueman-manager)")
        actions+=("󰅖  關閉視窗 (Exit)")
        
        local full_list=()
        if (( ${#device_entries[@]} > 0 )); then
            full_list+=("${device_entries[@]}")
            full_list+=("────────────────────────────────────────────────────────")
        fi
        full_list+=("${actions[@]}")
        
        local choice
        choice=$(printf "%s\n" "${full_list[@]}" | fzf --ansi \
            --prompt="󰂯 藍芽 > " \
            --header="$header" \
            --header-first \
            --layout=reverse \
            --border=rounded \
            --margin=1 \
            --no-info || true)
            
        local clean_choice
        clean_choice=$(echo -e "$choice" | sed 's/\x1b\[[0-9;]*m//g')
        
        [[ -z "$clean_choice" || "$clean_choice" =~ "關閉視窗" || "$clean_choice" =~ "───" ]] && exit 0
        
        case "$clean_choice" in
            *"關閉藍芽"*)
                bluetoothctl power off
                notify normal "藍芽" "藍芽已關閉"
                continue
                ;;
            *"進階藍芽管理員"*)
                blueman-manager &
                exit 0
                ;;
            *"搜尋附近新裝置"*)
                echo -e "\n正在搜尋附近藍芽裝置 (約 5 秒)..."
                notify low "藍芽" "正在掃描周圍藍芽裝置..."
                bluetoothctl --timeout 5 scan on 2>/dev/null || true
                sleep 0.5
                continue
                ;;
        esac
        
        local target_mac="${dev_mac["$clean_choice"]:-}"
        local is_conn="${dev_conn["$clean_choice"]:-}"
        if [[ -n "$target_mac" ]]; then
            if [[ "$is_conn" == "yes" ]]; then
                echo -e "\n正在中斷連線 \033[1;33m$target_mac\033[0m..."
                bluetoothctl disconnect "$target_mac" 2>/dev/null || true
                notify normal "藍芽" "已中斷藍芽裝置連線"
                sleep 0.8
            else
                echo -e "\n正在連線至 \033[1;34m$target_mac\033[0m..."
                notify low "藍芽" "正在嘗試連線至裝置..."
                if bluetoothctl connect "$target_mac" 2>/dev/null; then
                    notify normal "藍芽" "藍芽連線成功！"
                    sleep 0.8
                else
                    notify critical "藍芽" "連線失敗，請確認裝置已開機"
                    echo -e "\033[1;31m連線失敗\033[0m"
                    sleep 1.5
                fi
            fi
            continue
        fi
    done
}

run_menu
