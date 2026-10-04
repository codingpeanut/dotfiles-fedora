#!/usr/bin/env python3
# ==============================================================================
# notification-center.py - Lightweight Fuzzel-powered Notification Center for Mako
# ==============================================================================
import json
import subprocess
import sys
import shutil

def get_notifications():
    """Fetch all active and historical notifications from Mako."""
    notifications = []
    seen_ids = set()

    for cmd in [["makoctl", "list", "-j"], ["makoctl", "history", "-j"]]:
        try:
            res = subprocess.check_output(cmd, text=True, stderr=subprocess.DEVNULL)
            items = json.loads(res)
            if isinstance(items, list):
                if items and isinstance(items[0], list):
                    items = items[0]
                for n in items:
                    nid = n.get("id", {}).get("data") if isinstance(n.get("id"), dict) else n.get("id")
                    if nid and nid in seen_ids:
                        continue
                    if nid:
                        seen_ids.add(nid)
                    notifications.append(n)
        except Exception:
            pass

    return notifications

def is_dnd_active():
    try:
        modes = subprocess.check_output(
            ["makoctl", "mode"], text=True, stderr=subprocess.DEVNULL
        ).splitlines()
        return "do-not-disturb" in [m.strip() for m in modes]
    except Exception:
        return False

def main():
    if not shutil.which("fuzzel"):
        subprocess.run(["notify-send", "-a", "通知中心", "錯誤", "未安裝 Fuzzel 啟動器"])
        return

    notifications = get_notifications()
    dnd = is_dnd_active()

    # Build menu entries
    menu_lines = []
    dnd_text = "🔕 關閉勿擾模式" if dnd else "🔔 開啟勿擾模式"
    clear_text = "🗑️ 清除所有歷史通知"

    menu_lines.append(clear_text)
    menu_lines.append(dnd_text)

    item_map = {}
    if notifications:
        menu_lines.append("─────────────────────────────────────────────")
        for i, n in enumerate(notifications):
            app = n.get("app-name", {}).get("data", "") if isinstance(n.get("app-name"), dict) else n.get("app-name", "系統")
            summary = n.get("summary", {}).get("data", "") if isinstance(n.get("summary"), dict) else n.get("summary", "")
            body = n.get("body", {}).get("data", "") if isinstance(n.get("body"), dict) else n.get("body", "")

            app = app.strip() or "系統"
            summary = summary.replace("\n", " ").strip()
            body = body.replace("\n", " ").strip()

            line = f"[{app}] {summary}"
            if body:
                line += f" — {body}"
            # Truncate overly long display lines
            if len(line) > 85:
                line = line[:82] + "..."

            # Guarantee uniqueness in menu
            display_line = f"{i + 1}. {line}"
            menu_lines.append(display_line)
            item_map[display_line] = (app, summary, body)
    else:
        menu_lines.append("─────────────────────────────────────────────")
        menu_lines.append("（目前尚無歷史通知）")

    menu_payload = "\n".join(menu_lines)

    try:
        proc = subprocess.Popen(
            ["fuzzel", "--dmenu", "-p", "󰂚 通知中心 ❯ ", "-w", "58", "-l", str(min(14, len(menu_lines)))],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            text=True
        )
        selected, _ = proc.communicate(input=menu_payload)
        selected = selected.strip()
    except Exception:
        return

    if not selected or selected == "（目前尚無歷史通知）" or selected.startswith("────"):
        return

    if selected == clear_text:
        # Dismiss active notifications, restart mako to flush history buffer
        subprocess.run(["makoctl", "dismiss", "-a"], capture_output=True)
        subprocess.run(["pkill", "mako"], capture_output=True)
        subprocess.Popen(["nohup", "mako"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        subprocess.run(["pkill", "-RTMIN+9", "waybar"], capture_output=True)
        subprocess.run(["notify-send", "-a", "通知中心", "-t", "2000", "通知中心", "已清空所有歷史通知"])
    elif selected == dnd_text:
        if dnd:
            subprocess.run(["makoctl", "mode", "-r", "do-not-disturb"], capture_output=True)
            status_msg = "勿擾模式已關閉"
        else:
            subprocess.run(["makoctl", "mode", "-a", "do-not-disturb"], capture_output=True)
            status_msg = "勿擾模式已開啟（通知將靜默收錄）"
        subprocess.run(["pkill", "-RTMIN+9", "waybar"], capture_output=True)
        subprocess.run(["notify-send", "-a", "通知中心", "-t", "2000", "通知中心", status_msg])
    elif selected in item_map:
        app, summary, body = item_map[selected]
        # Copy to clipboard if wl-copy exists
        if shutil.which("wl-copy"):
            clip_text = f"{summary}\n{body}".strip() if body else summary
            subprocess.run(["wl-copy"], input=clip_text.encode())
        # Reshow notification in Mako
        subprocess.run(["notify-send", "-a", app, summary, body])

if __name__ == "__main__":
    main()
