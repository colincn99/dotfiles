#!/usr/bin/env python3
import os
import gi

gi.require_version("Gtk", "3.0")
gi.require_version("AyatanaAppIndicator3", "0.1")
from gi.repository import Gtk, GLib, AyatanaAppIndicator3

STATE_FILE = "/tmp/touhou_mouse_state"

# Built-in Ubuntu/Adwaita theme icon names
ICON_OFF = "input-keyboard-symbolic"
ICON_ON = "input-mouse-symbolic"

class ModeIndicator:
    def __init__(self):
        self.last_state = None
        self.indicator = AyatanaAppIndicator3.Indicator.new(
            "touhou-mouse-indicator",
            ICON_OFF,
            AyatanaAppIndicator3.IndicatorCategory.APPLICATION_STATUS,
        )
        self.indicator.set_status(AyatanaAppIndicator3.IndicatorStatus.ACTIVE)

        # Minimal right-click menu
        menu = Gtk.Menu()
        self.status_item = Gtk.MenuItem(label="Mode: Keyboard (OFF)")
        self.status_item.set_sensitive(False)
        menu.append(self.status_item)

        quit_item = Gtk.MenuItem(label="Quit Indicator")
        quit_item.connect("activate", Gtk.main_quit)
        menu.append(quit_item)

        menu.show_all()
        self.indicator.set_menu(menu)

        # Poll state file every 150ms
        GLib.timeout_add(150, self.check_state)

    def check_state(self):
        state = "OFF"
        if os.path.exists(STATE_FILE):
            try:
                with open(STATE_FILE, "r") as f:
                    state = f.read().strip()
            except Exception:
                pass

        if state != self.last_state:
            self.last_state = state
            if state == "ON":
                self.indicator.set_icon_full(ICON_ON, "Mouse Mode ON")
                self.status_item.set_label("Mode: Mouse (ON)")
            else:
                self.indicator.set_icon_full(ICON_OFF, "Keyboard Mode")
                self.status_item.set_label("Mode: Keyboard (OFF)")
        return True

if __name__ == "__main__":
    ModeIndicator()
    Gtk.main()

