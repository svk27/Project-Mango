#!/bin/bash

# Setup logging
LOG_FILE="/tmp/desktop-shortcut-run-result.txt"
> "$LOG_FILE" # Clear the log file on start

log() {
    echo "$1" | tee -a "$LOG_FILE"
}

log "Starting desktop shortcut configuration..."

# 1. Ensure the Desktop directory exists for the current user
DESKTOP_DIR="$HOME/Desktop"
mkdir -p "$DESKTOP_DIR"
log "Checked Desktop directory at $DESKTOP_DIR"

# 2. Copy the system-wide application shortcuts to your Desktop
# Added simple existence checks to prevent errors, even though software is assumed to exist.
if [ -f /usr/share/applications/code.desktop ]; then
    cp /usr/share/applications/code.desktop "$DESKTOP_DIR/"
    log "Copied VS Code shortcut."
else
    log "Warning: VS Code desktop file not found in /usr/share/applications/"
fi

if [ -f /usr/share/applications/github-desk.desktop ]; then
    cp /usr/share/applications/github-desk.desktop "$DESKTOP_DIR/github-desktop.desktop"
    log "Copied GitHub Desktop shortcut."
else
    log "Warning: GitHub Desktop desktop file not found in /usr/share/applications/"
fi

# 3. Carefully inject the flags right after the main executable path
log "Injecting command line flags..."

# For VS Code:
if [ -f "$DESKTOP_DIR/code.desktop" ]; then
    sed -i "s|^Exec=\([^ ]*\)|Exec=\1 --disable-gpu --no-sandbox --user-data-dir=$HOME/Desktop/vstemp |" "$DESKTOP_DIR/code.desktop"
    log "Updated VS Code shortcut flags."
fi

# For GitHub Desktop:
if [ -f "$DESKTOP_DIR/github-desktop.desktop" ]; then
    sed -i "s|^Exec=\([^ ]*\)|Exec=\1 --disable-gpu --no-sandbox |" "$DESKTOP_DIR/github-desktop.desktop"
    log "Updated GitHub Desktop shortcut flags."
fi

# 4. Make the shortcuts executable (Required by desktop environments like XFCE)
log "Setting executable permissions..."
[ -f "$DESKTOP_DIR/code.desktop" ] && chmod +x "$DESKTOP_DIR/code.desktop"
[ -f "$DESKTOP_DIR/github-desktop.desktop" ] && chmod +x "$DESKTOP_DIR/github-desktop.desktop"

# Note for Debian 13 / GNOME: If using GNOME, you might still need to right-click 
# the desktop icon and select "Allow Launching" on the first run.

log "Done! The modified shortcuts are ready on your Desktop."
