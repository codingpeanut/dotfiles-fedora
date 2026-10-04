#!/usr/bin/env python3
# ==============================================================================
# wifi-gui.py - Standalone Lightweight GTK3 Wi-Fi Manager for Niri / Wayland
# ==============================================================================
import os
import sys
import subprocess
import threading

import gi
gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
from gi.repository import Gtk, Gdk, GLib, Pango

GLib.set_prgname("wifi-manager")
GLib.set_application_name("Wi-Fi Manager")

class WifiManagerApp(Gtk.Window):
    def __init__(self):
        super().__init__(title="Wi-Fi Manager")
        self.set_wmclass("wifi-manager", "wifi-manager")
        self.set_default_size(540, 600)
        self.set_position(Gtk.WindowPosition.CENTER)

        self.scanning = False
        self.wifi_enabled = True
        self.active_ssid = None
        self.networks = [] # list of dicts: {ssid, signal, security, in_use, saved}

        # Handle keyboard shortcuts (Esc or Mod+Q / Ctrl+W to close)
        self.connect("key-press-event", self.on_key_press)
        self.connect("destroy", Gtk.main_quit)

        self.setup_ui()
        self.check_wifi_status_and_refresh()

    def setup_ui(self):
        # ----------------------------------------------------------------------
        # HeaderBar
        # ----------------------------------------------------------------------
        self.header = Gtk.HeaderBar()
        self.header.set_show_close_button(True)
        self.header.set_title("Wi-Fi 管理員")
        self.header.set_subtitle("正在載入網路狀態...")
        self.set_titlebar(self.header)

        # Wi-Fi Power Switch
        self.power_switch = Gtk.Switch()
        self.power_switch.set_valign(Gtk.Align.CENTER)
        self.power_switch.set_tooltip_text("開啟 / 關閉 Wi-Fi")
        self.switch_handler_id = self.power_switch.connect("state-set", self.on_power_switch_toggled)
        self.header.pack_start(self.power_switch)

        # Refresh / Rescan Button
        self.refresh_btn = Gtk.Button()
        self.refresh_icon = Gtk.Image.new_from_icon_name("view-refresh-symbolic", Gtk.IconSize.BUTTON)
        self.refresh_btn.set_image(self.refresh_icon)
        self.refresh_btn.set_tooltip_text("重新掃描周遭 Wi-Fi 基地台")
        self.refresh_btn.connect("clicked", lambda b: self.rescan_networks())
        self.header.pack_end(self.refresh_btn)

        # Spinner for scanning activity
        self.spinner = Gtk.Spinner()
        self.spinner.set_valign(Gtk.Align.CENTER)
        self.header.pack_end(self.spinner)

        # ----------------------------------------------------------------------
        # Main Layout
        # ----------------------------------------------------------------------
        main_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        self.add(main_box)

        # Notification / Info InfoBar (hidden by default)
        self.info_bar = Gtk.InfoBar()
        self.info_bar.set_show_close_button(True)
        self.info_bar.connect("response", lambda ib, resp: ib.hide())
        self.info_label = Gtk.Label()
        self.info_label.set_line_wrap(True)
        self.info_bar.get_content_area().add(self.info_label)
        self.info_bar.set_no_show_all(True)
        main_box.pack_start(self.info_bar, False, False, 0)

        # Stack to switch between Network List and "Wi-Fi Disabled" View
        self.stack = Gtk.Stack()
        self.stack.set_transition_type(Gtk.StackTransitionType.CROSSFADE)
        main_box.pack_start(self.stack, True, True, 0)

        # --- View 1: Wi-Fi Disabled Page ---
        disabled_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=16)
        disabled_box.set_valign(Gtk.Align.CENTER)
        disabled_box.set_halign(Gtk.Align.CENTER)

        disabled_icon = Gtk.Label()
        disabled_icon.set_markup("<span font='48'>󰖪</span>")
        disabled_box.pack_start(disabled_icon, False, False, 0)

        disabled_lbl = Gtk.Label()
        disabled_lbl.set_markup("<span font='14' weight='bold'>Wi-Fi 目前處於關閉狀態</span>")
        disabled_box.pack_start(disabled_lbl, False, False, 0)

        enable_btn = Gtk.Button(label="立即開啟 Wi-Fi")
        enable_btn.get_style_context().add_class("suggested-action")
        enable_btn.connect("clicked", lambda b: self.enable_wifi())
        disabled_box.pack_start(enable_btn, False, False, 0)

        self.stack.add_named(disabled_box, "disabled")

        # --- View 2: Network List Page ---
        list_container = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)

        self.scrolled = Gtk.ScrolledWindow()
        self.scrolled.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        list_container.pack_start(self.scrolled, True, True, 0)

        self.listbox = Gtk.ListBox()
        self.listbox.set_selection_mode(Gtk.SelectionMode.NONE)
        self.scrolled.add(self.listbox)

        self.stack.add_named(list_container, "networks")

        # ----------------------------------------------------------------------
        # Bottom Action Bar
        # ----------------------------------------------------------------------
        action_bar = Gtk.ActionBar()
        main_box.pack_end(action_bar, False, False, 0)

        editor_btn = Gtk.Button(label="進階設定 (nm-connection-editor)")
        editor_btn.connect("clicked", self.on_open_connection_editor)
        action_bar.pack_start(editor_btn)

        close_btn = Gtk.Button(label="關閉 (Esc)")
        close_btn.connect("clicked", lambda b: self.close())
        action_bar.pack_end(close_btn)

    def show_message(self, message, message_type=Gtk.MessageType.INFO):
        self.info_bar.set_message_type(message_type)
        self.info_label.set_text(message)
        self.info_bar.show_all()

    def on_key_press(self, widget, event):
        if event.keyval == Gdk.KEY_Escape:
            self.close()
            return True
        return False

    def on_open_connection_editor(self, button):
        subprocess.Popen(["nm-connection-editor"])

    # --------------------------------------------------------------------------
    # Wi-Fi Power Control
    # --------------------------------------------------------------------------
    def enable_wifi(self):
        self.power_switch.set_active(True)

    def on_power_switch_toggled(self, switch, state):
        def worker():
            cmd = "on" if state else "off"
            subprocess.run(["nmcli", "radio", "wifi", cmd], stdout=subprocess.DEVNULL)
            GLib.idle_add(self.check_wifi_status_and_refresh)

        threading.Thread(target=worker, daemon=True).start()
        return False

    # --------------------------------------------------------------------------
    # Network Status & Scanning
    # --------------------------------------------------------------------------
    def check_wifi_status_and_refresh(self):
        def worker():
            res = subprocess.run(["nmcli", "-fields", "WIFI", "g"], capture_output=True, text=True)
            status_text = res.stdout.strip().lower()
            enabled = "enabled" in status_text and "disabled" not in status_text

            # Get active connection
            res_active = subprocess.run(
                ["nmcli", "-t", "-f", "TYPE,NAME", "connection", "show", "--active"],
                capture_output=True, text=True
            )
            active_ssid = None
            for line in res_active.stdout.splitlines():
                if line.startswith("802-11-wireless:"):
                    active_ssid = line.split(":", 1)[1].strip()

            GLib.idle_add(self.apply_wifi_status, enabled, active_ssid)

        threading.Thread(target=worker, daemon=True).start()

    def apply_wifi_status(self, enabled, active_ssid):
        self.wifi_enabled = enabled
        self.active_ssid = active_ssid

        # Update switch without triggering event loop
        self.power_switch.handler_block(self.switch_handler_id)
        self.power_switch.set_active(enabled)
        self.power_switch.handler_unblock(self.switch_handler_id)

        if not enabled:
            self.header.set_subtitle("Wi-Fi 已關閉")
            self.stack.set_visible_child_name("disabled")
            self.refresh_btn.set_sensitive(False)
            self.spinner.stop()
            return

        self.refresh_btn.set_sensitive(True)
        self.stack.set_visible_child_name("networks")
        if active_ssid:
            self.header.set_subtitle(f"已連線至：{active_ssid}")
        else:
            self.header.set_subtitle("未連線至任何網路")

        self.load_networks_list()

    def rescan_networks(self):
        if self.scanning or not self.wifi_enabled:
            return
        self.scanning = True
        self.spinner.start()
        self.refresh_btn.set_sensitive(False)
        self.header.set_subtitle("正在掃描周遭 Wi-Fi...")

        def worker():
            subprocess.run(["nmcli", "device", "wifi", "rescan"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            GLib.idle_add(self.load_networks_list)

        threading.Thread(target=worker, daemon=True).start()

    def load_networks_list(self):
        self.spinner.start()

        def worker():
            # Get saved connections
            res_saved = subprocess.run(
                ["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show"],
                capture_output=True, text=True
            )
            saved_ssids = set()
            for line in res_saved.stdout.splitlines():
                parts = line.split(":")
                if len(parts) >= 2 and "wireless" in parts[1]:
                    saved_ssids.add(parts[0])

            # Get scanned AP list
            res_scan = subprocess.run(
                ["nmcli", "--terse", "--fields", "IN-USE,SSID,SIGNAL,SECURITY", "device", "wifi", "list"],
                capture_output=True, text=True
            )

            # Parse and deduplicate by best signal
            ap_map = {}
            for line in res_scan.stdout.splitlines():
                parts = line.split(":")
                if len(parts) < 4:
                    continue
                in_use = parts[0] == "*"
                ssid = parts[1].strip()
                if not ssid or ssid == "--":
                    continue
                try:
                    signal = int(parts[2])
                except ValueError:
                    signal = 0
                security = parts[3].strip()

                if ssid not in ap_map or signal > ap_map[ssid]["signal"] or in_use:
                    ap_map[ssid] = {
                        "ssid": ssid,
                        "signal": signal,
                        "security": security,
                        "in_use": in_use or (ssid == self.active_ssid),
                        "saved": ssid in saved_ssids
                    }

            # Sort: active first, then by signal strength descending
            sorted_nets = sorted(
                ap_map.values(),
                key=lambda x: (not x["in_use"], -x["signal"], x["ssid"].lower())
            )

            GLib.idle_add(self.render_network_rows, sorted_nets)

        threading.Thread(target=worker, daemon=True).start()

    def render_network_rows(self, networks):
        self.spinner.stop()
        self.scanning = False
        self.refresh_btn.set_sensitive(True)
        self.networks = networks

        # Clear existing rows
        for child in self.listbox.get_children():
            self.listbox.remove(child)

        if not networks:
            empty_row = Gtk.ListBoxRow()
            lbl = Gtk.Label(label="未搜尋到任何 Wi-Fi 網路，請嘗試點擊重新整理。")
            lbl.set_margin_top(40)
            lbl.set_margin_bottom(40)
            empty_row.add(lbl)
            self.listbox.add(empty_row)
            self.listbox.show_all()
            return

        for net in networks:
            row = Gtk.ListBoxRow()
            row_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=14)
            row_box.set_margin_start(16)
            row_box.set_margin_end(16)
            row_box.set_margin_top(10)
            row_box.set_margin_bottom(10)
            row.add(row_box)

            # Signal Icon
            sig = net["signal"]
            if sig >= 75:
                icon_glyph = "󰤨"
            elif sig >= 50:
                icon_glyph = "󰤥"
            elif sig >= 25:
                icon_glyph = "󰤢"
            else:
                icon_glyph = "󰤟"

            icon_lbl = Gtk.Label()
            icon_lbl.set_markup(f"<span font='18'>{icon_glyph}</span>")
            icon_lbl.set_valign(Gtk.Align.CENTER)
            row_box.pack_start(icon_lbl, False, False, 0)

            # Details: SSID & Security / Signal
            details_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
            details_box.set_valign(Gtk.Align.CENTER)

            ssid_lbl = Gtk.Label()
            ssid_lbl.set_markup(f"<b>{GLib.markup_escape_text(net['ssid'])}</b>")
            ssid_lbl.set_halign(Gtk.Align.START)
            ssid_lbl.set_ellipsize(Pango.EllipsizeMode.END)
            details_box.pack_start(ssid_lbl, False, False, 0)

            sec = net["security"]
            sec_text = "開放網路" if not sec or sec == "--" else f" {sec}"
            sub_lbl = Gtk.Label()
            sub_lbl.set_markup(f"<span color='#7aa2f7' size='small'>{sec_text}</span> • <span color='#9aa5ce' size='small'>訊號 {sig}%</span>")
            sub_lbl.set_halign(Gtk.Align.START)
            details_box.pack_start(sub_lbl, False, False, 0)

            row_box.pack_start(details_box, True, True, 0)

            # Status / Action Button
            if net["in_use"]:
                connected_tag = Gtk.Label()
                connected_tag.set_markup("<span color='#9ece6a' weight='bold'>✔ 已連線</span>")
                connected_tag.set_valign(Gtk.Align.CENTER)
                row_box.pack_start(connected_tag, False, False, 4)

                disconn_btn = Gtk.Button(label="中斷")
                disconn_btn.set_valign(Gtk.Align.CENTER)
                disconn_btn.get_style_context().add_class("destructive-action")
                disconn_btn.connect("clicked", lambda b, s=net["ssid"]: self.disconnect_network(s))
                row_box.pack_start(disconn_btn, False, False, 0)
            else:
                conn_btn = Gtk.Button(label="連線")
                conn_btn.set_valign(Gtk.Align.CENTER)
                if net["saved"]:
                    conn_btn.get_style_context().add_class("suggested-action")
                    conn_btn.set_tooltip_text("已儲存的網路，直接點擊連線")
                conn_btn.connect("clicked", lambda b, n=net: self.on_connect_clicked(n))
                row_box.pack_start(conn_btn, False, False, 0)

            self.listbox.add(row)

        self.listbox.show_all()

    # --------------------------------------------------------------------------
    # Connect / Disconnect Handlers
    # --------------------------------------------------------------------------
    def disconnect_network(self, ssid):
        self.spinner.start()
        self.header.set_subtitle(f"正在中斷連線：{ssid}...")

        def worker():
            subprocess.run(["nmcli", "connection", "down", ssid], stdout=subprocess.DEVNULL)
            GLib.idle_add(self.check_wifi_status_and_refresh)

        threading.Thread(target=worker, daemon=True).start()

    def on_connect_clicked(self, net):
        ssid = net["ssid"]

        # If already saved or open network without password:
        if net["saved"]:
            self.do_connect(ssid)
            return

        is_open = not net["security"] or net["security"] == "--"
        if is_open:
            self.do_connect(ssid)
            return

        # Encrypted and not saved: ask password via modal dialog
        self.show_password_dialog(net)

    def show_password_dialog(self, net):
        ssid = net["ssid"]
        dialog = Gtk.Dialog(
            title=f"連線至 {ssid}",
            transient_for=self,
            flags=Gtk.DialogFlags.MODAL | Gtk.DialogFlags.DESTROY_WITH_PARENT
        )
        dialog.set_default_size(380, 160)
        dialog.add_button("取消", Gtk.ResponseType.CANCEL)
        connect_btn = dialog.add_button("連線", Gtk.ResponseType.OK)
        connect_btn.get_style_context().add_class("suggested-action")

        content = dialog.get_content_area()
        content.set_spacing(10)
        content.set_margin_start(16)
        content.set_margin_end(16)
        content.set_margin_top(16)
        content.set_margin_bottom(10)

        prompt_lbl = Gtk.Label(label=f"請輸入 Wi-Fi「{ssid}」的安全性金鑰：")
        prompt_lbl.set_halign(Gtk.Align.START)
        content.pack_start(prompt_lbl, False, False, 0)

        # Entry with password toggle
        entry_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        pwd_entry = Gtk.Entry()
        pwd_entry.set_visibility(False)
        pwd_entry.set_activates_default(True)
        entry_box.pack_start(pwd_entry, True, True, 0)

        show_pwd_btn = Gtk.ToggleButton()
        show_pwd_btn.set_image(Gtk.Image.new_from_icon_name("view-conceal-symbolic", Gtk.IconSize.BUTTON))
        show_pwd_btn.set_tooltip_text("顯示/隱藏密碼")
        def on_toggle_pwd(btn):
            visible = btn.get_active()
            pwd_entry.set_visibility(visible)
            icon = "view-reveal-symbolic" if visible else "view-conceal-symbolic"
            btn.set_image(Gtk.Image.new_from_icon_name(icon, Gtk.IconSize.BUTTON))
        show_pwd_btn.connect("toggled", on_toggle_pwd)
        entry_box.pack_start(show_pwd_btn, False, False, 0)

        content.pack_start(entry_box, False, False, 0)
        dialog.set_default_response(Gtk.ResponseType.OK)
        dialog.show_all()

        response = dialog.run()
        password = pwd_entry.get_text().strip()
        dialog.destroy()

        if response == Gtk.ResponseType.OK and password:
            self.do_connect(ssid, password=password)

    def do_connect(self, ssid, password=None):
        self.spinner.start()
        self.header.set_subtitle(f"正在連線至 {ssid}...")
        self.info_bar.hide()

        def worker():
            if password:
                cmd = ["nmcli", "device", "wifi", "connect", ssid, "password", password]
            else:
                # Try connection up first (for saved connections), fallback to wifi connect
                res = subprocess.run(["nmcli", "connection", "up", ssid], capture_output=True, text=True)
                if res.returncode == 0:
                    GLib.idle_add(self.on_connect_success, ssid)
                    return
                cmd = ["nmcli", "device", "wifi", "connect", ssid]

            res = subprocess.run(cmd, capture_output=True, text=True)
            if res.returncode == 0:
                GLib.idle_add(self.on_connect_success, ssid)
            else:
                err_msg = res.stderr.strip() or res.stdout.strip() or "連線失敗，請檢查密碼或訊號狀態。"
                GLib.idle_add(self.on_connect_failure, ssid, err_msg)

        threading.Thread(target=worker, daemon=True).start()

    def on_connect_success(self, ssid):
        self.spinner.stop()
        self.show_message(f"✔ 成功連線至「{ssid}」！", Gtk.MessageType.INFO)
        self.check_wifi_status_and_refresh()

    def on_connect_failure(self, ssid, err_msg):
        self.spinner.stop()
        self.show_message(f"✘ 無法連線至「{ssid}」：{err_msg}", Gtk.MessageType.ERROR)
        self.check_wifi_status_and_refresh()

def main():
    app = WifiManagerApp()
    app.show_all()
    Gtk.main()

if __name__ == "__main__":
    main()
