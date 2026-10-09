#!/usr/bin/env python3
# ==============================================================================
# idle-manager.py - Smart Power & Idle Timeout Daemon for Niri (Wayland)
# Dynamically switches screen-off and suspend timeouts for AC vs Battery,
# reads ~/.config/energy-settings.json, and hot-reloads swayidle seamlessly.
# ==============================================================================
import os
import sys
import json
import time
import signal
import subprocess

CONFIG_PATH = os.path.expanduser("~/.config/energy-settings.json")
PID_FILE = "/tmp/idle-manager.pid"

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
                # Merge with defaults
                cfg = dict(DEFAULT_CONFIG)
                cfg["ac"] = {**DEFAULT_CONFIG["ac"], **data.get("ac", {})}
                cfg["battery"] = {**DEFAULT_CONFIG["battery"], **data.get("battery", {})}
                cfg["lock_on_blank"] = data.get("lock_on_blank", DEFAULT_CONFIG["lock_on_blank"])
                return cfg
        except Exception:
            pass
    return DEFAULT_CONFIG

def is_on_ac():
    ps_dir = "/sys/class/power_supply"
    if not os.path.isdir(ps_dir):
        return True  # Fallback for desktop

    has_battery = False
    ac_online = False

    try:
        for name in os.listdir(ps_dir):
            type_file = os.path.join(ps_dir, name, "type")
            online_file = os.path.join(ps_dir, name, "online")
            if os.path.isfile(type_file):
                try:
                    with open(type_file, "r") as f:
                        t = f.read().strip()
                    if t == "Battery":
                        has_battery = True
                    elif t in ("Mains", "AC") and os.path.isfile(online_file):
                        with open(online_file, "r") as f:
                            if f.read().strip() == "1":
                                ac_online = True
                except Exception:
                    pass
    except Exception:
        return True

    if not has_battery:
        return True
    return ac_online

class IdleManager:
    def __init__(self):
        self.swayidle_proc = None
        self.last_ac_state = None
        self.reload_requested = False
        self.running = True

    def kill_all_swayidle(self):
        try:
            subprocess.run(["pkill", "-u", str(os.getuid()), "-x", "swayidle"],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except Exception:
            pass
        if self.swayidle_proc:
            try:
                self.swayidle_proc.terminate()
                self.swayidle_proc.wait(timeout=0.5)
            except Exception:
                pass
            self.swayidle_proc = None

    def start_swayidle(self, cfg, on_ac):
        self.kill_all_swayidle()

        mode = "ac" if on_ac else "battery"
        mode_cfg = cfg.get(mode, DEFAULT_CONFIG[mode])
        screen_off_mins = mode_cfg.get("screen_off_mins", 10)
        suspend_mins = mode_cfg.get("suspend_mins", 30)
        lock_on_blank = cfg.get("lock_on_blank", True)

        screen_off_sec = max(0, int(screen_off_mins * 60))
        suspend_sec = max(0, int(suspend_mins * 60))

        cmd = ["swayidle", "-w"]

        # 1. Screen blanking & lock timeout
        if screen_off_sec > 0:
            if lock_on_blank:
                cmd.extend([
                    "timeout", str(screen_off_sec),
                    "swaylock -f; niri msg action power-off-monitors",
                    "resume",
                    "niri msg action power-on-monitors"
                ])
            else:
                cmd.extend([
                    "timeout", str(screen_off_sec),
                    "niri msg action power-off-monitors",
                    "resume",
                    "niri msg action power-on-monitors"
                ])

        # 2. System suspend timeout
        if suspend_sec > 0:
            # Suspend must occur at or after screen off
            if screen_off_sec > 0 and suspend_sec < screen_off_sec:
                suspend_sec = screen_off_sec + 60
            cmd.extend([
                "timeout", str(suspend_sec),
                "systemctl suspend"
            ])

        # 3. Always lock screen before going to sleep (e.g. lid closed)
        cmd.extend([
            "before-sleep", "swaylock -f"
        ])

        try:
            self.swayidle_proc = subprocess.Popen(
                cmd,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL
            )
        except Exception as e:
            print(f"[idle-manager] Error launching swayidle: {e}", file=sys.stderr)

    def handle_signal(self, signum, frame):
        if signum in (signal.SIGTERM, signal.SIGINT):
            self.running = False
            self.kill_all_swayidle()
            sys.exit(0)
        elif signum == signal.SIGUSR1:
            self.reload_requested = True

    def run(self):
        signal.signal(signal.SIGTERM, self.handle_signal)
        signal.signal(signal.SIGINT, self.handle_signal)
        signal.signal(signal.SIGUSR1, self.handle_signal)

        # Write PID file
        try:
            with open(PID_FILE, "w") as f:
                f.write(str(os.getpid()))
        except Exception:
            pass

        print(f"[idle-manager] Daemon started (PID {os.getpid()})")

        cfg = load_config()
        self.last_ac_state = is_on_ac()
        self.start_swayidle(cfg, self.last_ac_state)

        last_check_time = time.time()
        config_mtime = os.path.getmtime(CONFIG_PATH) if os.path.exists(CONFIG_PATH) else 0

        while self.running:
            try:
                time.sleep(2)
            except KeyboardInterrupt:
                break

            current_ac = is_on_ac()
            current_mtime = os.path.getmtime(CONFIG_PATH) if os.path.exists(CONFIG_PATH) else 0

            # Check if AC status changed or config file changed or reload requested
            if (current_ac != self.last_ac_state or
                current_mtime != config_mtime or
                self.reload_requested):

                self.reload_requested = False
                self.last_ac_state = current_ac
                config_mtime = current_mtime
                cfg = load_config()
                self.start_swayidle(cfg, current_ac)

        self.kill_all_swayidle()

def trigger_reload():
    if os.path.exists(PID_FILE):
        try:
            with open(PID_FILE, "r") as f:
                pid = int(f.read().strip())
            os.kill(pid, signal.SIGUSR1)
            print("[idle-manager] Sent reload signal to daemon.")
            return True
        except Exception:
            pass
    # If daemon is not running or signal failed, kill and restart
    try:
        subprocess.run(["pkill", "-f", "idle-manager.py"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        subprocess.Popen([sys.executable, __file__], start_new_session=True)
        print("[idle-manager] Restarted daemon.")
        return True
    except Exception as e:
        print(f"[idle-manager] Error restarting: {e}", file=sys.stderr)
        return False

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] in ("reload", "-r", "--reload"):
        trigger_reload()
        sys.exit(0)
    manager = IdleManager()
    manager.run()
