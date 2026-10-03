#!/usr/bin/env bash
# ==============================================================================
# wifi-menu.sh - Interactive Wi-Fi manager for Niri floating terminal
# ==============================================================================
set -euo pipefail

# Ensure terminal cursor is restored on exit
trap 'tput cnorm 2>/dev/null || true' EXIT

# Notification helper
notify() {
    local urgency="${1:-normal}"
    local title="$2"
    local msg="$3"
    if command -v notify-send >/dev/null 2>&1; then
        notify-send -u "$urgency" "$title" "$msg"
    fi
}

main_loop() {
    while true; do
        clear

        # Check Wi-Fi radio status
        wifi_status=$(nmcli -fields WIFI g 2>/dev/null | tail -n 1 | tr -d '[:space:]')

        if [[ "$wifi_status" =~ ^disabled ]]; then
            echo -e "\033[1;33m󰖪  Wi-Fi 目前處於關閉狀態\033[0m\n"
            options=(
                "󰖩  開啟 Wi-Fi (Turn Wi-Fi On)"
                "  開啟詳細網路設定 (nm-connection-editor)"
                "  關閉視窗 (Exit)"
            )
            if command -v fzf >/dev/null 2>&1; then
                choice=$(printf "%s\n" "${options[@]}" | fzf --reverse --no-info --prompt="  選擇操作 > ") || exit 0
            else
                select choice in "${options[@]}"; do break; done
            fi

            case "$choice" in
                *"開啟 Wi-Fi"*)
                    echo -e "\n\033[1;32m正在開啟 Wi-Fi...\033[0m"
                    nmcli radio wifi on
                    notify low "Wi-Fi" "Wi-Fi 已開啟，正在搜尋附近網路..."
                    sleep 2
                    continue
                    ;;
                *"詳細網路設定"*)
                    nm-connection-editor &
                    exit 0
                    ;;
                *)
                    exit 0
                    ;;
            esac
        fi

        echo -e "\033[1;34m󰖩  正在掃描周遭 Wi-Fi 網路...\033[0m"

        # Get active connection
        active_conn=$(nmcli -t -f TYPE,NAME connection show --active 2>/dev/null | grep '^802-11-wireless:' | cut -d: -f2 || true)

        # Scan APs
        raw_list=$(nmcli --terse --fields IN-USE,SSID,SIGNAL,SECURITY device wifi list 2>/dev/null || true)

        declare -A ssid_map
        declare -A sec_map
        declare -A sig_map
        declare -A in_use_map

        while IFS=':' read -r in_use ssid signal security; do
            [[ -z "$ssid" || "$ssid" == "--" ]] && continue
            current_best="${sig_map["$ssid"]:-0}"
            if (( signal >= current_best )); then
                sig_map["$ssid"]="$signal"
                sec_map["$ssid"]="$security"
                [[ "$in_use" == "*" ]] && in_use_map["$ssid"]="1"
            fi
        done <<< "$raw_list"

        sorted_ssids=$(for s in "${!sig_map[@]}"; do
            printf "%03d\t%s\n" "${sig_map["$s"]}" "$s"
        done | sort -rn | cut -f2-)

        network_entries=()
        while IFS= read -r s; do
            [[ -z "$s" ]] && continue
            sig="${sig_map["$s"]}"
            sec="${sec_map["$s"]}"

            if (( sig >= 75 )); then
                icon="󰤨"
            elif (( sig >= 50 )); then
                icon="󰤥"
            elif (( sig >= 25 )); then
                icon="󰤢"
            else
                icon="󰤟"
            fi

            lock="  "
            if [[ -n "$sec" && "$sec" != "--" ]]; then
                lock=" "
            fi

            if [[ -n "${in_use_map["$s"]:-}" || "$s" == "$active_conn" ]]; then
                display="󰄬 $icon  $s  ($sig%) $lock[已連線]"
            else
                display="   $icon  $s  ($sig%) $lock"
            fi

            network_entries+=("$display")
            ssid_map["$display"]="$s"
        done <<< "$sorted_ssids"

        action_entries=()
        if [[ -n "$active_conn" ]]; then
            action_entries+=("󰌙  中斷目前連線 ($active_conn)")
        fi
        action_entries+=("  重新搜尋網路 (Rescan)")
        action_entries+=("󰖪  關閉 Wi-Fi (Turn Off)")
        action_entries+=("  詳細連線設定 (nm-connection-editor)")
        action_entries+=("  關閉視窗 (Exit / Mod+Q)")

        menu_items=()
        menu_items+=("${action_entries[@]}")
        menu_items+=("───────────────────────────────────────────────────")
        menu_items+=("${network_entries[@]}")

        header="  󰖩 Wi-Fi 管理員 (Niri 浮動視窗)
  操作：[Enter] 選取/連線  |  [Esc]/[q]/[Mod+Q] 關閉視窗"

        if command -v fzf >/dev/null 2>&1; then
            selected=$(printf "%s\n" "${menu_items[@]}" | fzf \
                --reverse \
                --no-info \
                --header="$header" \
                --prompt="  搜尋/選擇 > " \
                --pointer="▶" || true)
        else
            echo "$header"
            select selected in "${menu_items[@]}"; do break; done
        fi

        [[ -z "$selected" || "$selected" == *"關閉視窗"* ]] && exit 0
        [[ "$selected" =~ ─── ]] && continue

        case "$selected" in
            *"關閉 Wi-Fi"*)
                nmcli radio wifi off
                notify normal "Wi-Fi" "Wi-Fi 已關閉"
                exit 0
                ;;
            *"重新搜尋網路"*)
                echo -e "\n\033[1;36m正在重新掃描 Wi-Fi...\033[0m"
                nmcli device wifi rescan 2>/dev/null || true
                sleep 1.2
                continue
                ;;
            *"詳細連線設定"*)
                nm-connection-editor &
                exit 0
                ;;
            *"中斷目前連線"*)
                nmcli connection down "$active_conn" 2>/dev/null || true
                notify normal "Wi-Fi" "已中斷連線：$active_conn"
                exit 0
                ;;
        esac

        target_ssid="${ssid_map["$selected"]:-}"
        [[ -z "$target_ssid" ]] && continue

        if [[ "$target_ssid" == "$active_conn" ]]; then
            echo -e "\n\033[1;32m目前已連線至 $target_ssid\033[0m"
            sleep 1
            exit 0
        fi

        # Check existing saved profile
        saved_conn=$(nmcli -t -f NAME connection show 2>/dev/null | grep -Fx "$target_ssid" || true)

        if [[ -n "$saved_conn" ]]; then
            echo -e "\n\033[1;34m正在連線至已知網路 $target_ssid...\033[0m"
            if nmcli connection up "$target_ssid" 2>/dev/null; then
                echo -e "\033[1;32m✔ 成功連線至 $target_ssid！\033[0m"
                notify normal "Wi-Fi" "成功連線至 $target_ssid"
                sleep 1
                exit 0
            else
                echo -e "\033[1;31m✘ 連線失敗，請稍後重試。\033[0m"
                sleep 2
                continue
            fi
        fi

        # Not saved: check if password required
        target_sec="${sec_map["$target_ssid"]:-}"
        if [[ -n "$target_sec" && "$target_sec" != "--" ]]; then
            echo ""
            read -r -s -p "請輸入 $target_ssid 的密碼 (留空取消): " pass
            echo ""
            [[ -z "$pass" ]] && continue

            echo -e "\033[1;34m正在連線至 $target_ssid...\033[0m"
            if nmcli device wifi connect "$target_ssid" password "$pass" 2>/dev/null; then
                echo -e "\033[1;32m✔ 成功連線至 $target_ssid！\033[0m"
                notify normal "Wi-Fi" "成功連線至 $target_ssid"
                sleep 1
                exit 0
            else
                echo -e "\033[1;31m✘ 連線失敗，密碼可能不正確。\033[0m"
                sleep 2
                continue
            fi
        else
            echo -e "\n\033[1;34m正在連線至開放網路 $target_ssid...\033[0m"
            if nmcli device wifi connect "$target_ssid" 2>/dev/null; then
                echo -e "\033[1;32m✔ 成功連線至 $target_ssid！\033[0m"
                notify normal "Wi-Fi" "成功連線至 $target_ssid"
                sleep 1
                exit 0
            else
                echo -e "\033[1;31m✘ 連線失敗。\033[0m"
                sleep 2
                continue
            fi
        fi
    done
}

main_loop
