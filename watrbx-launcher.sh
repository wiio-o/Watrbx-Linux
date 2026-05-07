#!/usr/bin/env bash
# ============================================================
#  Watrbx Linux Installer
#  Simple, clean, works.
# ============================================================

set -euo pipefail

WINEPREFIX="$HOME/.local/share/watrbx/wine"
INSTALLER_URL="https://www.watrbx.wtf/RobloxPlayerLauncher.exe"
VERSION_DIR="$WINEPREFIX/drive_c/users/$USER/AppData/Local/Watrbx/Versions"
LOG_FILE="$HOME/.local/share/watrbx/installer.log"

mkdir -p "$(dirname "$LOG_FILE")"

info()    { echo "[INFO] $*"; echo "[$(date '+%Y-%m-%d %H:%M:%S')] INFO: $*" >> "$LOG_FILE"; }
success() { echo "[OK] $*"; echo "[$(date '+%Y-%m-%d %H:%M:%S')] OK: $*" >> "$LOG_FILE"; }
warn()    { echo "[WARN] $*"; echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARN: $*" >> "$LOG_FILE"; }
die()     { echo "[ERROR] $*" >&2; echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $*" >> "$LOG_FILE"; exit 1; }

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
    wine "$TEMP_INSTALLER" 2>&1 | tee -a "$LOG_FILE" | grep -v "fixme:" || true

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

uninstall() {
    print_banner
    warn "This will remove:"
    echo "  - Wine prefix: $WINEPREFIX"
    echo "  - Desktop files"
    echo "  - URI handler configuration"
    echo ""
    read -rp "Continue? [y/N] " CONFIRM

    if [[ "${CONFIRM,,}" != "y" ]]; then
        info "Uninstall cancelled"
        exit 0
    fi

    info "Uninstalling Watrbx..."

    # Kill Wine
    WINEPREFIX="$WINEPREFIX" wineserver -k 2>/dev/null || true

    # Remove Wine prefix
    if [ -d "$WINEPREFIX" ]; then
        rm -rf "$WINEPREFIX"
        success "Removed Wine prefix"
    fi

    # Remove desktop files
    rm -f ~/.local/share/applications/watrbx-player.desktop
    rm -f ~/.local/share/applications/watrbx-studio.desktop
    update-desktop-database ~/.local/share/applications 2>/dev/null || true
    success "Removed desktop files"

    # Remove logs
    rm -f "$LOG_FILE"

    success "Uninstall complete!"
}

show_debug() {
    print_banner
    echo "=== Debug Information ==="
    echo ""
    echo "Wine version: $(wine --version 2>/dev/null || echo 'NOT INSTALLED')"
    echo "Wine prefix: $WINEPREFIX"
    echo "Prefix exists: $([ -d "$WINEPREFIX" ] && echo 'Yes' || echo 'No')"
    echo ""

    local PLAYER_EXE STUDIO_EXE
    PLAYER_EXE=$(get_player_exe)
    STUDIO_EXE=$(get_studio_exe)

    echo "Player exe: ${PLAYER_EXE:-NOT FOUND}"
    echo "Studio exe: ${STUDIO_EXE:-NOT FOUND}"
    echo ""

    echo "Desktop files:"
    [ -f ~/.local/share/applications/watrbx-player.desktop ] && echo "  [OK] watrbx-player.desktop" || echo "  [!!] watrbx-player.desktop missing"
    [ -f ~/.local/share/applications/watrbx-studio.desktop ] && echo "  [OK] watrbx-studio.desktop" || echo "  [!!] watrbx-studio.desktop missing"
    echo ""

    echo "Firefox profile:"
    local FF_PROFILE
    FF_PROFILE=$(find "$HOME/.mozilla/firefox" -maxdepth 1 \
        \( -name "*.default-release" -o -name "*.default" \) -type d 2>/dev/null | head -n1 || true)

    if [ -n "$FF_PROFILE" ]; then
        echo "  Found: $FF_PROFILE"
        if [ -f "$FF_PROFILE/handlers.json" ]; then
            if grep -q "watrbx-player" "$FF_PROFILE/handlers.json" 2>/dev/null; then
                echo "  [OK] URI handler configured"
            else
                echo "  [!!] URI handler NOT configured"
            fi
        else
            echo "  [!!] handlers.json missing"
        fi
    else
        echo "  [!!] Firefox profile not found"
    fi
    echo ""

    echo "Log file: $LOG_FILE"
    if [ -f "$LOG_FILE" ]; then
        echo "Last 10 lines:"
        tail -10 "$LOG_FILE" | sed 's/^/  /'
    else
        echo "  No log file"
    fi
}

# -- Main --------------------------------------------------

case "${1:-install}" in
    --uninstall)
        uninstall
        exit 0
        ;;
    --debug)
        show_debug
        exit 0
        ;;
    --update)
        print_banner
        info "Updating Watrbx..."
        update_watrbx
        exit 0
        ;;
    install)
        # Continue to installation below
        ;;
    *)
        echo "Usage: $0 [--uninstall|--debug|--update]"
        exit 1
        ;;
esac

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
echo "  Commands:"
echo "    $0 --update     Update Watrbx"
echo "    $0 --debug      Show debug info"
echo "    $0 --uninstall  Remove everything"
echo ""
echo "  Log: $LOG_FILE"
echo ""
