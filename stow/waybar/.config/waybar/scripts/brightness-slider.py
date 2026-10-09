#!/usr/bin/env python3
# ==============================================================================
# brightness-slider.py - Modern GTK3 Graphical Brightness Slider Popup
# Tokyo Night theme, real-time scroll/drag adjustment, presets & keyboard nav
# ==============================================================================
import os
import sys
import subprocess

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
BRIGHTNESS_CONTROL = os.path.join(SCRIPT_DIR, "brightness-control.sh")

# Fallback to TUI menu if GTK is unavailable
try:
    import gi
    gi.require_version('Gtk', '3.0')
    gi.require_version('Gdk', '3.0')
    from gi.repository import Gtk, Gdk, GLib
except Exception:
    tui_script = os.path.join(SCRIPT_DIR, "brightness-menu.sh")
    if os.path.exists(tui_script):
        os.execv("/bin/bash", ["bash", tui_script] + sys.argv[1:])
    sys.exit(1)

def get_brightness():
    try:
        cmd = [BRIGHTNESS_CONTROL, "get"] if os.path.exists(BRIGHTNESS_CONTROL) else ["brightness-control", "get"]
        out = subprocess.check_output(cmd, text=True, stderr=subprocess.DEVNULL).strip()
        return int(out)
    except Exception:
        return 50

def set_brightness(val):
    try:
        cmd = [BRIGHTNESS_CONTROL, "set", str(int(val))] if os.path.exists(BRIGHTNESS_CONTROL) else ["brightness-control", "set", str(int(val))]
        subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except Exception:
        pass

def is_niri_touchpad_natural_scroll():
    """Check if natural-scroll is enabled in ~/.config/niri/config.kdl under touchpad block."""
    candidates = [
        os.path.expanduser("~/.config/niri/config.kdl"),
        os.path.expanduser("~/dev/dotfiles-fedora/stow/niri/.config/niri/config.kdl"),
    ]
    for config_path in candidates:
        if os.path.exists(config_path):
            try:
                with open(config_path, "r", encoding="utf-8") as f:
                    in_touchpad = False
                    for line in f:
                        stripped = line.strip()
                        if stripped.startswith("//"):
                            continue
                        if "touchpad" in stripped and "{" in stripped:
                            in_touchpad = True
                            continue
                        if in_touchpad:
                            if "}" in stripped:
                                in_touchpad = False
                            elif stripped.startswith("natural-scroll"):
                                return True
                    return False
            except Exception:
                pass
    return True

class BrightnessSliderWindow(Gtk.Window):
    def __init__(self):
        super().__init__(title="螢幕亮度調整")
        self.set_wmclass("brightness-slider", "brightness-slider")
        self.set_role("brightness-slider")
        self.set_position(Gtk.WindowPosition.CENTER)
        self.set_default_size(440, 180)
        self.set_resizable(False)

        self.pending_apply_id = None
        self.current_val = get_brightness()

        # Load Tokyo Night CSS
        self.apply_css()

        # Main Layout Box
        vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=14)
        vbox.set_margin_top(18)
        vbox.set_margin_bottom(18)
        vbox.set_margin_start(24)
        vbox.set_margin_end(24)
        self.add(vbox)

        # Header: Icon + Title + Value
        header_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        vbox.pack_start(header_box, False, False, 0)

        icon_label = Gtk.Label(label="󰃠")
        icon_label.get_style_context().add_class("title-icon")
        header_box.pack_start(icon_label, False, False, 0)

        title_label = Gtk.Label(label="螢幕亮度")
        title_label.get_style_context().add_class("title-label")
        header_box.pack_start(title_label, False, False, 0)

        header_box.pack_start(Gtk.Box(), True, True, 0)  # Spacer

        self.pct_label = Gtk.Label(label=f"{self.current_val}%")
        self.pct_label.get_style_context().add_class("pct-label")
        header_box.pack_end(self.pct_label, False, False, 0)

        # Slider (Gtk.Scale)
        self.adj = Gtk.Adjustment(
            value=self.current_val,
            lower=1.0,
            upper=100.0,
            step_increment=1.0,
            page_increment=5.0,
            page_size=0.0
        )
        self.scale = Gtk.Scale(
            orientation=Gtk.Orientation.HORIZONTAL,
            adjustment=self.adj
        )
        self.scale.set_draw_value(False)
        self.scale.connect("value-changed", self.on_slider_changed)
        self.scale.connect("scroll-event", self.on_scroll_event)
        vbox.pack_start(self.scale, False, False, 0)

        # Preset Buttons Box
        btn_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        btn_box.set_homogeneous(True)
        vbox.pack_start(btn_box, False, False, 0)

        presets = [("25%", 25), ("50%", 50), ("75%", 75), ("100%", 100)]
        for label, val in presets:
            btn = Gtk.Button(label=label)
            btn.get_style_context().add_class("preset-btn")
            btn.connect("clicked", self.create_preset_handler(val))
            btn_box.pack_start(btn, True, True, 0)

        # Keyboard Navigation Hint Footer
        hint_label = Gtk.Label(label="󰌌 方向鍵 [← / →] 微調游標  |  [Enter / Esc] 確定")
        hint_label.get_style_context().add_class("hint-label")
        vbox.pack_start(hint_label, False, False, 0)

        # Make scale grab focus by default so arrow keys immediately control the slider cursor
        self.scale.set_can_focus(True)
        GLib.idle_add(self.scale.grab_focus)

        # Key bindings and Events
        self.connect("key-press-event", self.on_key_press)
        self.connect("scroll-event", self.on_scroll_event)
        self.connect("destroy", Gtk.main_quit)

    def apply_css(self):
        css = b"""
        window {
            background-color: #1a1b26;
            color: #c0caf5;
        }
        .title-icon {
            font-family: "JetBrainsMono Nerd Font", monospace;
            font-size: 20px;
            color: #e0af68;
        }
        .title-label {
            font-family: "JetBrainsMono Nerd Font", "Noto Sans", sans-serif;
            font-size: 15px;
            font-weight: bold;
            color: #c0caf5;
        }
        .pct-label {
            font-family: "JetBrainsMono Nerd Font", monospace;
            font-size: 22px;
            font-weight: bold;
            color: #e0af68;
        }
        scale trough {
            min-height: 12px;
            border-radius: 6px;
            background-color: #24283b;
            border: 1px solid rgba(255, 255, 255, 0.1);
        }
        scale highlight {
            min-height: 12px;
            border-radius: 6px;
            background-color: #e0af68;
        }
        scale slider {
            min-width: 26px;
            min-height: 26px;
            margin: -7px 0;
            border-radius: 13px;
            background-color: #ff9e64;
            border: 3px solid #1a1b26;
            box-shadow: 0 0 6px rgba(255, 158, 100, 0.6);
            background-image: none;
        }
        scale slider:focus, scale slider:hover {
            background-color: #7aa2f7;
            border-color: #ffffff;
            box-shadow: 0 0 8px rgba(122, 162, 247, 0.8);
        }
        button.preset-btn {
            background-color: #24283b;
            color: #c0caf5;
            border-radius: 6px;
            border: 1px solid rgba(255, 255, 255, 0.1);
            padding: 4px 0px;
            font-family: "JetBrainsMono Nerd Font", monospace;
            font-size: 12px;
            font-weight: 600;
        }
        button.preset-btn:hover {
            background-color: #414868;
            color: #ffffff;
            border-color: #7aa2f7;
        }
        .hint-label {
            font-family: "JetBrainsMono Nerd Font", monospace;
            font-size: 11px;
            color: #7aa2f7;
            margin-top: 2px;
        }
        """
        provider = Gtk.CssProvider()
        provider.load_from_data(css)
        Gtk.StyleContext.add_provider_for_screen(
            Gdk.Screen.get_default(),
            provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )

    def on_slider_changed(self, scale):
        val = int(scale.get_value())
        self.pct_label.set_text(f"{val}%")

        # Debounce the system brightnessctl/ddcutil call (40ms)
        if self.pending_apply_id is not None:
            GLib.source_remove(self.pending_apply_id)

        self.pending_apply_id = GLib.timeout_add(40, self.do_apply_brightness, val)

    def do_apply_brightness(self, val):
        self.pending_apply_id = None
        set_brightness(val)
        return False

    def create_preset_handler(self, target_val):
        def handler(button):
            self.scale.set_value(target_val)
        return handler

    def on_scroll_event(self, widget, event):
        natural_scroll = is_niri_touchpad_natural_scroll()
        delta = 0

        if event.direction == Gdk.ScrollDirection.SMOOTH:
            deltas = event.get_scroll_deltas()
            if len(deltas) == 3:
                _, dx, dy = deltas
            else:
                dx, dy = deltas

            # Determine whether horizontal swipe (touchpad) or vertical scroll (mouse wheel / touchpad)
            if abs(dx) > abs(dy):
                # Horizontal swipe: 觸控板左右滑動
                # 需求：往右變大 (+5)，往左變小 (-5)
                # 自然捲動 (natural-scroll) 開啟時：向右滑動產生 dx < 0
                # 自然捲動關閉時：向右滑動產生 dx > 0
                if natural_scroll:
                    if dx < 0:
                        delta = 5
                    elif dx > 0:
                        delta = -5
                else:
                    if dx > 0:
                        delta = 5
                    elif dx < 0:
                        delta = -5
            else:
                # Vertical scroll: 滑鼠滾輪上下滾動
                # 需求：滾輪上是調亮 (+5)，下是調暗 (-5)
                is_touchpad = False
                source_dev = event.get_source_device()
                if source_dev and source_dev.get_source() == Gdk.InputSource.TOUCHPAD:
                    is_touchpad = True

                if is_touchpad and natural_scroll:
                    if dy > 0:
                        delta = 5
                    elif dy < 0:
                        delta = -5
                else:
                    if dy < 0:
                        delta = 5
                    elif dy > 0:
                        delta = -5

        elif event.direction == Gdk.ScrollDirection.UP:
            delta = 5
        elif event.direction == Gdk.ScrollDirection.DOWN:
            delta = -5
        elif event.direction == Gdk.ScrollDirection.RIGHT:
            delta = -5 if natural_scroll else 5
        elif event.direction == Gdk.ScrollDirection.LEFT:
            delta = 5 if natural_scroll else -5

        if delta != 0:
            new_val = max(1, min(100, self.scale.get_value() + delta))
            self.scale.set_value(new_val)
            return True
        return False

    def on_key_press(self, widget, event):
        keyval = event.keyval
        state = event.state

        # Shift key enables 1% ultra-fine tuning; regular arrows do 2% or 5%
        step = 1 if (state & Gdk.ModifierType.SHIFT_MASK) else 5

        if keyval in (Gdk.KEY_Escape, Gdk.KEY_q, Gdk.KEY_Q, Gdk.KEY_Return, Gdk.KEY_KP_Enter, Gdk.KEY_space):
            self.close()
            return True
        elif keyval in (Gdk.KEY_Left, Gdk.KEY_h, Gdk.KEY_H):
            new_val = max(1, min(100, self.scale.get_value() - step))
            self.scale.set_value(new_val)
            return True
        elif keyval in (Gdk.KEY_Right, Gdk.KEY_l, Gdk.KEY_L):
            new_val = max(1, min(100, self.scale.get_value() + step))
            self.scale.set_value(new_val)
            return True
        elif keyval in (Gdk.KEY_Down, Gdk.KEY_j, Gdk.KEY_J):
            new_val = max(1, min(100, self.scale.get_value() - step))
            self.scale.set_value(new_val)
            return True
        elif keyval in (Gdk.KEY_Up, Gdk.KEY_k, Gdk.KEY_K):
            new_val = max(1, min(100, self.scale.get_value() + step))
            self.scale.set_value(new_val)
            return True
        return False

def main():
    win = BrightnessSliderWindow()
    win.show_all()
    Gtk.main()

if __name__ == "__main__":
    main()
