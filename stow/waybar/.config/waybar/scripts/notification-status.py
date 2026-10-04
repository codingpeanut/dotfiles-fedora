#!/usr/bin/env python3
# ==============================================================================
# notification-status.py - Real-time Mako notification status for Waybar module
# ==============================================================================
import json
import subprocess
import sys

def get_status():
    dnd = False
    try:
        modes = subprocess.check_output(
            ["makoctl", "mode"], text=True, stderr=subprocess.DEVNULL
        ).splitlines()
        dnd = "do-not-disturb" in [m.strip() for m in modes]
    except Exception:
        pass

    count = 0
    try:
        data = subprocess.check_output(
            ["makoctl", "history", "-j"], text=True, stderr=subprocess.DEVNULL
        )
        items = json.loads(data)
        if isinstance(items, list):
            # Mako sometimes nests items in a top-level list
            if items and isinstance(items[0], list):
                items = items[0]
            count = len(items)
    except Exception:
        pass

    if dnd:
        return {
            "text": "󰂛",
            "class": "dnd",
            "tooltip": (
                f"通知中心 (勿擾模式開啟中)\n"
                f"• 歷史通知: {count} 則\n\n"
                f"• 左鍵：開啟通知中心 (Fuzzel)\n"
                f"• 右鍵：切換勿擾模式\n"
                f"• 中鍵：清除所有通知"
            ),
        }
    elif count > 0:
        return {
            "text": f"󰂚 {count}",
            "class": "unread",
            "tooltip": (
                f"通知中心 ({count} 則未處理通知)\n\n"
                f"• 左鍵：開啟通知中心 (Fuzzel)\n"
                f"• 右鍵：切換勿擾模式\n"
                f"• 中鍵：清除所有通知"
            ),
        }
    else:
        return {
            "text": "󰂚",
            "class": "normal",
            "tooltip": (
                "通知中心 (尚無歷史通知)\n\n"
                "• 左鍵：開啟通知中心 (Fuzzel)\n"
                "• 右鍵：切換勿擾模式\n"
                "• 中鍵：清除所有通知"
            ),
        }

if __name__ == "__main__":
    print(json.dumps(get_status(), ensure_ascii=False))
