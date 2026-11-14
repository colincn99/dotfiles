#!/bin/bash
set -e

TOUHOU_DIR="$(dirname "$(readlink -f "$0")")"
SERVICE_FILE="/etc/systemd/system/touhou-mouse.service"
DESKTOP_FILE="$HOME/.config/autostart/touhou-tray.desktop"
STATE_FILE="/tmp/touhou_mouse_state"

# --- Uninstall Routine ---
if [[ "$1" == "--uninstall" ]]; then
    echo "Uninstalling Touhou Mouse Mode..."

    # 1. Stop and disable systemd service
    if systemctl list-unit-files | grep -q "^touhou-mouse.service"; then
        sudo systemctl stop touhou-mouse.service 2>/dev/null || true
        sudo systemctl disable touhou-mouse.service 2>/dev/null || true
    fi

    # 2. Remove systemd service file and reload
    if [ -f "$SERVICE_FILE" ]; then
        sudo rm -f "$SERVICE_FILE"
        sudo systemctl daemon-reload
    fi

    # 3. Stop tray indicator and remove autostart entry
    pkill -f "touhou_tray.py" 2>/dev/null || true
    rm -f "$DESKTOP_FILE"

    # 4. Clean up temporary state file
    sudo rm -f "$STATE_FILE"

    echo "Touhou Mouse Mode uninstalled cleanly."
    exit 0
fi

# --- Install Routine ---
echo "Setting up Touhou Mouse Mode from $TOUHOU_DIR..."

# 1. Install dependencies
sudo apt update
sudo apt install -y python3-evdev python3-gi gir1.2-ayatanaappindicator3-0.1

# Ensure uinput kernel module loads on boot
echo "uinput" | sudo tee /etc/modules-load.d/uinput.conf >/dev/null
sudo modprobe uinput

# 2. Ensure Python scripts are executable
chmod 755 "$TOUHOU_DIR/touhou_mouse.py" "$TOUHOU_DIR/touhou_tray.py"

# 3. Install systemd service (644 root:root)
sed "s|__TOUHOU_DIR__|$TOUHOU_DIR|g" "$TOUHOU_DIR/touhou-mouse.service" | \
    sudo install -m 644 -o root -g root /dev/stdin "$SERVICE_FILE"

sudo systemctl daemon-reload
sudo systemctl enable touhou-mouse.service
sudo systemctl restart touhou-mouse.service

# 4. Install XDG Autostart desktop entry (644 user)
mkdir -p "$HOME/.config/autostart"
sed "s|__TOUHOU_DIR__|$TOUHOU_DIR|g" "$TOUHOU_DIR/touhou-tray.desktop" > "$DESKTOP_FILE"
chmod 644 "$DESKTOP_FILE"

# Restart tray indicator in the current desktop session
pkill -f "touhou_tray.py" 2>/dev/null || true
nohup /usr/bin/python3 "$TOUHOU_DIR/touhou_tray.py" >/dev/null 2>&1 &

echo "Touhou Mouse Mode setup complete!"

