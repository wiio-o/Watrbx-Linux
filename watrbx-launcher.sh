#!/usr/bin/env bash
# ============================================================
#  Watrbx Linux Installer
#  Simple, clean, works.
# ============================================================

set -euo pipefail

WINEPREFIX="$HOME/.local/share/watrbx/wine"
INSTALLER_URL="https://www.watrbx.wtf/RobloxPlayerLauncher.exe"
VERSION_DIR="$WINEPREFIX/drive_c/users/$USER/AppData/Local/Watrbx/Versions"

info()    { echo "[INFO] $*"; }
success() { echo "[OK] $*"; }
warn()    { echo "[WARN] $*"; }
die()     { echo "[ERROR] $*" >&2; exit 1; }

print_banner() {
    echo ""
    echo " +----------------------------------+"
    echo " |   Watrbx Linux Installer v2.0    |"
    echo " +----------------------------------+"
    echo ""
}

install_deps() {
    info "Installing dependencies..."

    if command -v dnf &>/dev/null; then
        sudo dnf install -y wine winetricks curl python3 || warn "Some packages failed"
    elif command -v pacman &>/dev/null; then
        sudo pacman -S --noconfirm wine winetricks curl python3 || warn "Some packages failed"
    elif command -v apt-get &>/dev/null; then
        sudo apt-get update -qq
        sudo apt-get install -y wine wine32 winetricks curl python3 || warn "Some packages failed"
    elif command -v zypper &>/dev/null; then
        sudo zypper install -y wine winetricks curl python3 || warn "Some packages failed"
    else
        warn "Unknown package manager. Install wine, winetricks, curl, python3 manually."
        return
    fi

    success "Dependencies installed"
}

get_player_exe() {
    find "$VERSION_DIR" -name "RobloxPlayerLauncher.exe" 2>/dev/null | head -n1 || true
}

get_studio_exe() {
    find "$VERSION_DIR" -name "RobloxStudioLauncherBeta.exe" 2>/dev/null | head -n1 || true
}

update_desktop_files() {
    local PLAYER_PATH="$1"
    local STUDIO_PATH="$2"

    # Player desktop file
    if [ -n "$PLAYER_PATH" ]; then
        cat > ~/.local/share/applications/watrbx-player.desktop << DESKTOP
[Desktop Entry]
Name=Watrbx Player
Type=Application
Exec=env WINEPREFIX="$WINEPREFIX" wine "$PLAYER_PATH" %u
Icon=B7CC_RobloxPlayerLauncher.0
StartupNotify=true
StartupWMClass=robloxplayerlauncher.exe
MimeType=x-scheme-handler/watrbx-player;
DESKTOP
        success "Player desktop file updated"
    fi

    # Studio desktop file
    if [ -n "$STUDIO_PATH" ]; then
        cat > ~/.local/share/applications/watrbx-studio.desktop << DESKTOP
[Desktop Entry]
Name=Watrbx Studio
Type=Application
Exec=env WINEPREFIX="$WINEPREFIX" wine "$STUDIO_PATH"
Icon=B7CC_RobloxStudioLauncherBeta.0
StartupNotify=true
StartupWMClass=robloxstudiolauncherbeta.exe
Categories=Development;
DESKTOP
        success "Studio desktop file updated"
    fi

    update-desktop-database ~/.local/share/applications 2>/dev/null || true
    xdg-mime default watrbx-player.desktop x-scheme-handler/watrbx-player 2>/dev/null || true
}

update_watrbx() {
    info "Downloading Watrbx installer..."

    local TEMP_INSTALLER="/tmp/watrbx_installer.exe"
    curl -sL "$INSTALLER_URL" -o "$TEMP_INSTALLER" || die "Download failed"

    info "Running installer..."
    export WINEPREFIX
    wine "$TEMP_INSTALLER" 2>&1 | grep -v "fixme:" || true

    rm -f "$TEMP_INSTALLER"

    local PLAYER_EXE STUDIO_EXE
    PLAYER_EXE=$(get_player_exe)
    STUDIO_EXE=$(get_studio_exe)

    if [ -n "$PLAYER_EXE" ] || [ -n "$STUDIO_EXE" ]; then
        success "Watrbx installed/updated"
        update_desktop_files "$PLAYER_EXE" "$STUDIO_EXE"
    else
        die "Installation failed"
    fi
}

fix_firefox() {
    info "Configuring Firefox..."

    local FF_PROFILE
    FF_PROFILE=$(find "$HOME/.mozilla/firefox" -maxdepth 1 \
        \( -name "*.default-release" -o -name "*.default" \) -type d 2>/dev/null | head -n1 || true)

    if [ -z "$FF_PROFILE" ]; then
        warn "Firefox profile not found"
        return
    fi

    if [ ! -f "$FF_PROFILE/handlers.json" ]; then
        warn "Open Firefox first, then re-run installer"
        return
    fi

    cp "$FF_PROFILE/handlers.json" "$FF_PROFILE/handlers.json.bak"
    python3 - "$FF_PROFILE/handlers.json" << 'PYEOF'
import json, sys
with open(sys.argv[1]) as f:
    data = json.load(f)
if "schemes" not in data:
    data["schemes"] = {}
data["schemes"]["watrbx-player"] = {"action": 4}
with open(sys.argv[1], "w") as f:
    json.dump(data, f, indent=2)
PYEOF
    success "Firefox configured"
}

# -- Main -----------------------------------

print_banner

# Check and install Wine
if ! command -v wine &>/dev/null; then
    info "Wine not found"
    read -rp "Install dependencies? [Y/n] " INSTALL
    if [[ "${INSTALL,,}" != "n" ]]; then
        install_deps
    else
        die "Wine required. Install manually."
    fi
fi

info "Wine: $(wine --version)"

# Create Wine prefix if needed
if [ ! -d "$WINEPREFIX" ]; then
    info "Creating Wine prefix..."
    mkdir -p "$WINEPREFIX"
    WINEPREFIX="$WINEPREFIX" wineboot --init
    success "Wine prefix created"
fi

# Install/Update Watrbx
PLAYER_EXE=$(get_player_exe)
STUDIO_EXE=$(get_studio_exe)

if [ -z "$PLAYER_EXE" ] && [ -z "$STUDIO_EXE" ]; then
    info "Installing Watrbx..."
    update_watrbx
else
    if [ -n "$PLAYER_EXE" ]; then
        success "Player found: $(basename "$(dirname "$PLAYER_EXE")")"
    fi
    if [ -n "$STUDIO_EXE" ]; then
        success "Studio found: $(basename "$(dirname "$STUDIO_EXE")")"
    fi

    read -rp "Update? [y/N] " UPDATE
    if [[ "${UPDATE,,}" == "y" ]]; then
        update_watrbx
    else
        update_desktop_files "$PLAYER_EXE" "$STUDIO_EXE"
    fi
fi

# Fix Firefox
fix_firefox

echo ""
success "Installation complete!"
echo ""
echo "  To play games:"
echo "  1. Fully quit and restart Firefox"
echo "  2. Go to watrbx.wtf"
echo "  3. Click Play on any game"
echo ""
if [ -n "$(get_studio_exe)" ]; then
    echo "  To launch Studio:"
    echo "  - Search 'Watrbx Studio' in your app launcher"
    echo ""
fi
