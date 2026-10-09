#!/usr/bin/env python3
# ==============================================================================
# energy-menu.py - Modern GTK3 Energy & Sleep Management Panel
# Allows adjusting power profile (performance/balanced/power-saver),
# and separate idle screen blank / system suspend timeouts for AC vs Battery.
# ==============================================================================
import os
import sys
import json
import subprocess

try:
    import gi
    gi.require_version('Gtk', '3.0')
    gi.require_version('Gdk', '3.0')
    from gi.repository import Gtk, Gdk, GLib
except Exception as e:
    print(f"Error loading GTK3: {e}", file=sys.stderr)
    sys.exit(1)

CONFIG_PATH = os.path.expanduser("~/.config/energy-settings.json")
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
POWER_PROFILE_SCRIPT = os.path.join(SCRIPT_DIR, "power-profile.sh")
IDLE_MANAGER_SCRIPT = os.path.join(SCRIPT_DIR, "idle-manager.py")

DEFAULT_CONFIG = {
    "ac": {
        "screen_off_mins": 10,
        "suspend_mins": 30
    },
    "battery": {
        "screen_off_mins": 5,
        "suspend_mins": 15
    },
    "lock_on_blank": True
}

def load_config():
    if os.path.exists(CONFIG_PATH):
        try:
            with open(CONFIG_PATH, "r", encoding="utf-8") as f:
                data = json.load(f)
                cfg = dict(DEFAULT_CONFIG)
                cfg["ac"] = {**DEFAULT_CONFIG["ac"], **data.get("ac", {})}
                cfg["battery"] = {**DEFAULT_CONFIG["battery"], **data.get("battery", {})}
                cfg["lock_on_blank"] = data.get("lock_on_blank", DEFAULT_CONFIG["lock_on_blank"])
                return cfg
        except Exception:
            pass
    return dict(DEFAULT_CONFIG)

def save_config(cfg):
    try:
        os.makedirs(os.path.dirname(CONFIG_PATH), exist_ok=True)
        with open(CONFIG_PATH, "w", encoding="utf-8") as f:
            json.dump(cfg, f, indent=4, ensure_ascii=False)
        # Notify idle-manager
        if os.path.exists(IDLE_MANAGER_SCRIPT):
            subprocess.Popen([sys.executable, IDLE_MANAGER_SCRIPT, "reload"],
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        elif subprocess.run(["which", "idle-manager"], stdout=subprocess.DEVNULL).returncode == 0:
            subprocess.Popen(["idle-manager", "reload"],
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except Exception as e:
        print(f"Error saving config: {e}", file=sys.stderr)

def get_current_power_profile():
    try:
        out = subprocess.check_output(["powerprofilesctl", "get"], text=True, stderr=subprocess.DEVNULL).strip()
        return out
    except Exception:
        return "balanced"

def set_power_profile(profile):
    try:
        if os.path.exists(POWER_PROFILE_SCRIPT):
            subprocess.run([POWER_PROFILE_SCRIPT, "set", profile], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        else:
            subprocess.run(["powerprofilesctl", "set", profile], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except Exception:
        pass

class EnergyMenuWindow(Gtk.Window):
    def __init__(self):
        super().__init__(title="能源與睡眠設定")
        self.set_wmclass("energy-menu", "energy-menu")
        self.set_role("energy-menu")
        self.set_position(Gtk.WindowPosition.CENTER)
        self.set_default_size(480, 520)
        self.set_resizable(False)

        self.cfg = load_config()
        self.current_profile = get_current_power_profile()
        self.profile_buttons = {}

        self.apply_css()
        self.build_ui()

        self.connect("key-press-event", self.on_key_press)
        self.connect("destroy", Gtk.main_quit)

    def apply_css(self):
        css = b"""
        window {
            background-color: #1a1b26;
            color: #c0caf5;
        }
        .header-box {
            padding: 4px 0 10px 0;
            border-bottom: 1px solid rgba(255, 255, 255, 0.08);
        }
        .header-title {
            font-family: "JetBrainsMono Nerd Font", "Noto Sans", sans-serif;
            font-size: 16px;
            font-weight: bold;
            color: #c0caf5;
        }
        .header-sub {
            font-size: 12px;
            color: #565f89;
        }
        .section-label {
            font-family: "JetBrainsMono Nerd Font", "Noto Sans", sans-serif;
            font-size: 13px;
            font-weight: bold;
            color: #7aa2f7;
            margin-top: 6px;
            margin-bottom: 4px;
        }
        .card-box {
            background-color: rgba(36, 40, 59, 0.85);
            border: 1px solid rgba(255, 255, 255, 0.08);
            border-radius: 10px;
            padding: 10px 14px;
        }
        .profile-btn {
            background-color: rgba(26, 27, 38, 0.7);
            border: 1px solid rgba(255, 255, 255, 0.1);
            border-radius: 8px;
            color: #c0caf5;
            padding: 8px 12px;
            font-family: "JetBrainsMono Nerd Font", "Noto Sans", sans-serif;
            font-size: 13px;
            font-weight: 500;
            transition: all 0.2s ease;
        }
        .profile-btn:hover {
            background-color: rgba(65, 72, 104, 0.95);
            color: #ffffff;
            border-color: #7aa2f7;
        }
        .profile-active-performance {
            background-color: rgba(247, 118, 142, 0.25);
            border-color: #f7768e;
            color: #f7768e;
            font-weight: bold;
        }
        .profile-active-balanced {
            background-color: rgba(122, 162, 247, 0.25);
            border-color: #7aa2f7;
            color: #7aa2f7;
            font-weight: bold;
        }
        .profile-active-power-saver {
            background-color: rgba(158, 206, 106, 0.25);
            border-color: #9ece6a;
            color: #9ece6a;
            font-weight: bold;
        }
        .item-title {
            font-size: 13px;
            color: #c0caf5;
        }
        combobox button {
            background-color: #1f2335;
            border: 1px solid rgba(255, 255, 255, 0.12);
            border-radius: 6px;
            color: #c0caf5;
            font-size: 12px;
            padding: 4px 8px;
        }
        combobox button:hover {
            border-color: #7aa2f7;
        }
        checkbutton check {
            border-radius: 4px;
            background-color: #1f2335;
            border: 1px solid rgba(255, 255, 255, 0.2);
            min-height: 16px;
            min-width: 16px;
        }
        checkbutton check:checked {
            background-color: #7aa2f7;
            border-color: #7aa2f7;
            color: #15161e;
        }
        .status-msg {
            font-size: 12px;
            color: #9ece6a;
            font-family: "JetBrainsMono Nerd Font", monospace;
        }
        .hint-text {
            font-size: 11px;
            color: #565f89;
            font-family: "JetBrainsMono Nerd Font", monospace;
        }
        """
        provider = Gtk.CssProvider()
        provider.load_from_data(css)
        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(),
            provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )

    def build_ui(self):
        main_vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        main_vbox.set_margin_top(16)
        main_vbox.set_margin_bottom(16)
        main_vbox.set_margin_start(20)
        main_vbox.set_margin_end(20)
        self.add(main_vbox)

        # Header Box
        header_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        header_box.get_style_context().add_class("header-box")

        icon_label = Gtk.Label(label="󱐋")
        icon_label.set_markup('<span font="22" color="#e0af68">󱐋</span>')
        header_box.pack_start(icon_label, False, False, 0)

        title_vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        title_label = Gtk.Label(label="能源與睡眠管理", xalign=0)
        title_label.get_style_context().add_class("header-title")
        sub_label = Gtk.Label(label="自訂電源效能模式、閒置螢幕關閉與系統睡眠時間", xalign=0)
        sub_label.get_style_context().add_class("header-sub")
        title_vbox.pack_start(title_label, False, False, 0)
        title_vbox.pack_start(sub_label, False, False, 0)
        header_box.pack_start(title_vbox, True, True, 0)

        main_vbox.pack_start(header_box, False, False, 0)

        # -------------------------------------------------------------
        # Section 1: Power Profile Buttons
        # -------------------------------------------------------------
        sec1_label = Gtk.Label(label="󰾅 系統能源模式", xalign=0)
        sec1_label.get_style_context().add_class("section-label")
        main_vbox.pack_start(sec1_label, False, False, 0)

        profile_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        profile_box.set_homogeneous(True)
        main_vbox.pack_start(profile_box, False, False, 0)

        profiles = [
            ("performance", " 高效能"),
            ("balanced", "󰾅 平衡"),
            ("power-saver", " 省電")
        ]
        for key, text in profiles:
            btn = Gtk.Button(label=text)
            btn.get_style_context().add_class("profile-btn")
            btn.connect("clicked", self.create_profile_handler(key))
            profile_box.pack_start(btn, True, True, 0)
            self.profile_buttons[key] = btn

        self.update_profile_button_styles()

        # -------------------------------------------------------------
        # Section 2: Plugged-in (AC) Settings Card
        # -------------------------------------------------------------
        sec2_label = Gtk.Label(label="󰚥 插電狀態設定 (On AC Power)", xalign=0)
        sec2_label.get_style_context().add_class("section-label")
        main_vbox.pack_start(sec2_label, False, False, 0)

        ac_card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        ac_card.get_style_context().add_class("card-box")
        main_vbox.pack_start(ac_card, False, False, 0)

        ac_screen_options = [
            ("1 分鐘", 1), ("3 分鐘", 3), ("5 分鐘", 5),
            ("10 分鐘", 10), ("15 分鐘", 15), ("30 分鐘", 30), ("從不 (Never)", 0)
        ]
        ac_card.pack_start(
            self.create_combo_row("󰍹 關閉螢幕", "ac", "screen_off_mins", ac_screen_options),
            False, False, 0
        )

        ac_suspend_options = [
            ("5 分鐘", 5), ("10 分鐘", 10), ("15 分鐘", 15),
            ("30 分鐘", 30), ("1 小時", 60), ("從不 (Never)", 0)
        ]
        ac_card.pack_start(
            self.create_combo_row("󰤄 系統睡眠", "ac", "suspend_mins", ac_suspend_options),
            False, False, 0
        )

        # -------------------------------------------------------------
        # Section 3: Battery Settings Card
        # -------------------------------------------------------------
        sec3_label = Gtk.Label(label="󰂄 電池狀態設定 (On Battery)", xalign=0)
        sec3_label.get_style_context().add_class("section-label")
        main_vbox.pack_start(sec3_label, False, False, 0)

        bat_card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        bat_card.get_style_context().add_class("card-box")
        main_vbox.pack_start(bat_card, False, False, 0)

        bat_screen_options = [
            ("1 分鐘", 1), ("2 分鐘", 2), ("3 分鐘", 3),
            ("5 分鐘", 5), ("10 分鐘", 10), ("15 分鐘", 15), ("從不 (Never)", 0)
        ]
        bat_card.pack_start(
            self.create_combo_row("󰍹 關閉螢幕", "battery", "screen_off_mins", bat_screen_options),
            False, False, 0
        )

        bat_suspend_options = [
            ("3 分鐘", 3), ("5 分鐘", 5), ("10 分鐘", 10),
            ("15 分鐘", 15), ("30 分鐘", 30), ("從不 (Never)", 0)
        ]
        bat_card.pack_start(
            self.create_combo_row("󰤄 系統睡眠", "battery", "suspend_mins", bat_suspend_options),
            False, False, 0
        )

        # -------------------------------------------------------------
        # Section 4: Security & Options
        # -------------------------------------------------------------
        lock_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        lock_box.set_margin_top(4)

        self.lock_check = Gtk.CheckButton(label=" 閒置關閉螢幕時自動鎖定（swaylock）")
        self.lock_check.set_active(self.cfg.get("lock_on_blank", True))
        self.lock_check.connect("toggled", self.on_lock_check_toggled)
        lock_box.pack_start(self.lock_check, True, True, 0)
        main_vbox.pack_start(lock_box, False, False, 0)

        # -------------------------------------------------------------
        # Footer: Status & Hints
        # -------------------------------------------------------------
        footer_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        footer_box.set_margin_top(6)

        self.status_label = Gtk.Label(label="✓ 設定即時生效", xalign=0)
        self.status_label.get_style_context().add_class("status-msg")
        footer_box.pack_start(self.status_label, True, True, 0)

        hint_label = Gtk.Label(label="[Esc] 關閉", xalign=1)
        hint_label.get_style_context().add_class("hint-text")
        footer_box.pack_start(hint_label, False, False, 0)

        main_vbox.pack_start(footer_box, False, False, 0)

    def create_combo_row(self, label_text, mode_key, setting_key, options):
        row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        lbl = Gtk.Label(label=label_text, xalign=0)
        lbl.get_style_context().add_class("item-title")
        row.pack_start(lbl, True, True, 0)

        combo = Gtk.ComboBoxText()
        current_val = self.cfg.get(mode_key, {}).get(setting_key, 0)

        active_idx = 0
        for idx, (opt_label, opt_val) in enumerate(options):
            combo.append(str(opt_val), opt_label)
            if opt_val == current_val:
                active_idx = idx

        combo.set_active(active_idx)
        combo.connect("changed", self.create_combo_handler(mode_key, setting_key, combo))
        row.pack_start(combo, False, False, 0)
        return row

    def create_combo_handler(self, mode_key, setting_key, combo):
        def handler(_):
            val_id = combo.get_active_id()
            if val_id is not None:
                val = int(val_id)
                self.cfg[mode_key][setting_key] = val
                save_config(self.cfg)
                self.flash_status("✓ 設定已自動儲存並生效")
        return handler

    def on_lock_check_toggled(self, widget):
        self.cfg["lock_on_blank"] = widget.get_active()
        save_config(self.cfg)
        self.flash_status("✓ 鎖定策略已更新")

    def create_profile_handler(self, profile):
        def handler(_):
            set_power_profile(profile)
            self.current_profile = profile
            self.update_profile_button_styles()
            self.flash_status(f"✓ 已切換至 {profile} 模式")
        return handler

    def update_profile_button_styles(self):
        for key, btn in self.profile_buttons.items():
            ctx = btn.get_style_context()
            ctx.remove_class("profile-active-performance")
            ctx.remove_class("profile-active-balanced")
            ctx.remove_class("profile-active-power-saver")
            if key == self.current_profile:
                ctx.add_class(f"profile-active-{key}")

    def flash_status(self, text):
        self.status_label.set_text(text)
        GLib.timeout_add(3000, lambda: self.status_label.set_text("✓ 設定即時生效") or False)

    def on_key_press(self, widget, event):
        if event.keyval in (Gdk.KEY_Escape, Gdk.KEY_q):
            self.destroy()
            return True
        return False

def main():
    win = EnergyMenuWindow()
    win.show_all()
    Gtk.main()

if __name__ == "__main__":
    main()
