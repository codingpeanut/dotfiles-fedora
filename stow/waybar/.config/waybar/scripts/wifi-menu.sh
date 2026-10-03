#!/usr/bin/env bash
# ==============================================================================
# wifi-menu.sh - Interactive Wi-Fi selector (runs in desktop_popup window)
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
        
        # Check Wi-Fi radio status
        local wifi_status
        wifi_status=$(nmcli -fields WIFI g 2>/dev/null | tail -n 1 | tr -d '[:space:]')
        
        # Active Wi-Fi connection
        local active_conn
        active_conn=$(nmcli -t -f TYPE,NAME connection show --active 2>/dev/null | grep '^802-11-wireless:' | cut -d: -f2 || true)
        
        local header="󰖩 Wi-Fi 網路管理"
        if [[ "$wifi_status" =~ ^disabled ]]; then
            header+=$'\n狀態: [已關閉] | 操作: [Enter] 選擇  [Esc/q/Mod+Q] 關閉視窗'
            local opts=("󰖩  開啟 Wi-Fi (Turn Wi-Fi On)" "  開啟進階網路設定 (nm-connection-editor)" "󰅖  關閉視窗 (Exit)")
            local choice
            choice=$(printf "%s\n" "${opts[@]}" | fzf --ansi --prompt="󰖩 Wi-Fi > " --header="$header" --layout=reverse --border=rounded --no-info || true)
            case "$choice" in
                *"開啟 Wi-Fi"*)
                    nmcli radio wifi on
                    notify low "Wi-Fi" "Wi-Fi 已開啟，正在搜尋附近網路..."
                    sleep 1.5
                    continue
                    ;;
                *"進階網路設定"*)
                    nm-connection-editor &
                    exit 0
                    ;;
                *)
                    exit 0
                    ;;
            esac
        fi
        
        if [[ -n "$active_conn" ]]; then
            header+=$'\n狀態: [已連線: '"$active_conn"'] | 操作: [Enter] 選擇  [Esc/q/Mod+Q] 關閉視窗'
        else
            header+=$'\n狀態: [未連線] | 操作: [Enter] 選擇  [Esc/q/Mod+Q] 關閉視窗'
        fi
        
        # Scan APs
        local raw_list
        raw_list=$(nmcli --terse --fields IN-USE,SSID,SIGNAL,SECURITY device wifi list 2>/dev/null || true)
        
        declare -A ssid_map=()
        declare -A sec_map=()
        declare -A sig_map=()
        declare -A in_use_map=()
        
        while IFS=':' read -r in_use ssid signal security; do
            [[ -z "$ssid" || "$ssid" == "--" ]] && continue
            local cur="${sig_map["$ssid"]:-0}"
            if (( signal >= cur )); then
                sig_map["$ssid"]="$signal"
                sec_map["$ssid"]="$security"
                [[ "$in_use" == "*" ]] && in_use_map["$ssid"]="1"
            fi
        done <<< "$raw_list"
        
        local sorted_ssids
        sorted_ssids=$(for s in "${!sig_map[@]}"; do
            printf "%03d\t%s\n" "${sig_map["$s"]}" "$s"
        done | sort -rn | cut -f2-)
        
        local network_entries=()
        while IFS= read -r s; do
            [[ -z "$s" ]] && continue
            local sig="${sig_map["$s"]}"
            local sec="${sec_map["$s"]}"
            
            local icon="󰤟"
            if (( sig >= 75 )); then icon="󰤨"
            elif (( sig >= 50 )); then icon="󰤥"
            elif (( sig >= 25 )); then icon="󰤢"; fi
            
            local lock=""
            if [[ -n "$sec" && "$sec" != "--" ]]; then lock=" "; fi
            
            local display
            if [[ -n "${in_use_map["$s"]:-}" || "$s" == "$active_conn" ]]; then
                display=$(printf "\033[1;32m󰄬 %s  %-24s (%2d%%) %s[已連線]\033[0m" "$icon" "$s" "$sig" "$lock")
            else
                display=$(printf "   %s  %-24s (%2d%%) %s" "$icon" "$s" "$sig" "$lock")
            fi
            
            network_entries+=("$display")
            # Clean string for mapping
            local clean_display
            clean_display=$(echo -e "$display" | sed 's/\x1b\[[0-9;]*m//g')
            ssid_map["$clean_display"]="$s"
        done <<< "$sorted_ssids"
        
        local actions=()
        if [[ -n "$active_conn" ]]; then
            actions+=("󰌙  中斷目前連線 ($active_conn)")
        fi
        actions+=("  重新搜尋網路 (Rescan)")
        actions+=("󰖪  關閉 Wi-Fi (Turn Off)")
        actions+=("  開啟進階網路設定 (nm-connection-editor)")
        actions+=("󰅖  關閉視窗 (Exit)")
        
        local full_list=()
        full_list+=("${network_entries[@]}")
        full_list+=("────────────────────────────────────────────────────────")
        full_list+=("${actions[@]}")
        
        local choice
        choice=$(printf "%s\n" "${full_list[@]}" | fzf --ansi \
            --prompt="󰖩 Wi-Fi > " \
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
            *"關閉 Wi-Fi"*)
                nmcli radio wifi off
                notify normal "Wi-Fi" "Wi-Fi 已關閉"
                continue
                ;;
            *"重新搜尋網路"*)
                notify low "Wi-Fi" "正在重新整理附近網路..."
                nmcli device wifi rescan 2>/dev/null || true
                sleep 1.2
                continue
                ;;
            *"進階網路設定"*)
                nm-connection-editor &
                exit 0
                ;;
            *"中斷目前連線"*)
                nmcli connection down "$active_conn" 2>/dev/null || true
                notify normal "Wi-Fi" "已中斷連線：$active_conn"
                sleep 0.8
                continue
                ;;
        esac
        
        local target_ssid="${ssid_map["$clean_choice"]:-}"
        if [[ -n "$target_ssid" ]]; then
            if [[ "$target_ssid" == "$active_conn" ]]; then
                echo "目前已連線至 $target_ssid"
                sleep 1
                continue
            fi
            
            # Check saved
            local is_saved
            is_saved=$(nmcli -t -f NAME connection show 2>/dev/null | grep -Fx "$target_ssid" || true)
            if [[ -n "$is_saved" ]]; then
                echo -e "\n正在連線至已知網路 \033[1;34m$target_ssid\033[0m..."
                if nmcli connection up "$target_ssid" 2>/dev/null; then
                    notify normal "Wi-Fi" "成功連線至 $target_ssid"
                    sleep 1
                    exit 0
                else
                    echo -e "\033[1;31m連線失敗\033[0m"
                    sleep 1.5
                fi
            else
                local target_sec="${sec_map["$target_ssid"]:-}"
                if [[ -n "$target_sec" && "$target_sec" != "--" ]]; then
                    echo ""
                    echo -e "網路 \033[1;33m$target_ssid\033[0m 需要安全性密碼 ($target_sec)"
                    read -r -s -p "請輸入密碼 (按 Enter 確認): " wifi_pass
                    echo ""
                    [[ -z "$wifi_pass" ]] && continue
                    
                    echo -e "\n正在嘗試連線至 \033[1;34m$target_ssid\033[0m..."
                    if nmcli device wifi connect "$target_ssid" password "$wifi_pass" 2>/dev/null; then
                        notify normal "Wi-Fi" "成功連線至 $target_ssid"
                        sleep 1
                        exit 0
                    else
                        notify critical "Wi-Fi" "密碼錯誤或連線逾時"
                        echo -e "\033[1;31m連線失敗，請檢查密碼\033[0m"
                        sleep 2
                    fi
                else
                    echo -e "\n正在連線至開放網路 \033[1;34m$target_ssid\033[0m..."
                    if nmcli device wifi connect "$target_ssid" 2>/dev/null; then
                        notify normal "Wi-Fi" "成功連線至 $target_ssid"
                        sleep 1
                        exit 0
                    else
                        echo -e "\033[1;31m連線失敗\033[0m"
                        sleep 1.5
                    fi
                fi
            fi
        fi
    done
}

run_menu
