#!/usr/bin/env python3
"""
Trigger native Blueman right-click context menu via DBus StatusNotifierItem.
"""
import dbus
import subprocess
import time
import sys

def open_blueman_menu():
    # 1. Ensure blueman-applet is running
    p = subprocess.run(["pgrep", "-f", "blueman-applet"], stdout=subprocess.DEVNULL)
    if p.returncode != 0:
        subprocess.Popen(["blueman-applet"])
        time.sleep(0.5)

    try:
        bus = dbus.SessionBus()
    except Exception:
        subprocess.Popen(["blueman-manager"])
        return

    called = False

    # 2. Query StatusNotifierWatcher to find blueman SNI service
    try:
        watcher = bus.get_object("org.kde.StatusNotifierWatcher", "/StatusNotifierWatcher")
        props = dbus.Interface(watcher, "org.freedesktop.DBus.Properties")
        items = props.Get("org.kde.StatusNotifierWatcher", "RegisteredStatusNotifierItems")
        for item in items:
            if "/" in item:
                srv, path = item.split("/", 1)
                path = "/" + path
            else:
                srv = item
                path = "/StatusNotifierItem"

            try:
                sni_obj = bus.get_object(srv, path)
                sni_props = dbus.Interface(sni_obj, "org.freedesktop.DBus.Properties")
                app_id = str(sni_props.Get("org.kde.StatusNotifierItem", "Id"))
                if "blueman" in app_id.lower() or "blueman" in srv.lower() or "blueman" in path.lower():
                    sni = dbus.Interface(sni_obj, "org.kde.StatusNotifierItem")
                    sni.ContextMenu(0, 0)
                    called = True
                    break
            except Exception:
                continue
    except Exception:
        pass

    # 3. Direct well-known service fallback
    if not called:
        for srv in ["org.blueman.Applet", "org.blueman"]:
            for path in ["/org/blueman/sni", "/StatusNotifierItem", "/"]:
                try:
                    sni_obj = bus.get_object(srv, path)
                    sni = dbus.Interface(sni_obj, "org.kde.StatusNotifierItem")
                    sni.ContextMenu(0, 0)
                    called = True
                    break
                except Exception:
                    pass
            if called:
                break

    # 4. Final fallback: open blueman-manager if ContextMenu couldn't be invoked
    if not called:
        subprocess.Popen(["blueman-manager"])

if __name__ == "__main__":
    open_blueman_menu()
