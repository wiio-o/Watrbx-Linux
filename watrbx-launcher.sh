#!/usr/bin/env bash
# ============================================================
#  Watrbx Linux Launcher
#  Supports: Fedora, Arch, Ubuntu, Debian, openSUSE + derivatives
#
#  Usage:
#    ./watrbx-launcher.sh                     -> install/setup
#    ./watrbx-launcher.sh "watrbx-player://…" -> launch from browser
#    ./watrbx-launcher.sh --play [PLACE-ID]   -> join by place ID
#    ./watrbx-launcher.sh --debug             -> debug info
#    ./watrbx-launcher.sh --fix-firefox       -> fix Firefox URI handler
#    ./watrbx-launcher.sh --clear-logs        -> clear log files
#    ./watrbx-launcher.sh --reset             -> wipe prefix and reinstall
# ============================================================

LOG_FILE="$HOME/.local/share/watrbx/launcher.log"
LOCKFILE="/tmp/watrbx.lock"
COOKIE_HELPER="/tmp/watrbx-cookies.py"
WINE_LOG="/tmp/watrbx-wine.log"

mkdir -p "$(dirname "$LOG_FILE")"
> "$LOG_FILE"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] === Launcher called ===" >> "$LOG_FILE"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Args: $(printf '[%s] ' "$@")" >> "$LOG_FILE"

set -euo pipefail

# ── Config ────────────────────────────────────────────────
REVIVAL_NAME="Watrbx"
INSTALLER_URL="https://www.watrbx.wtf/RobloxPlayerLauncher.exe"
INSTALLER_EXE="RobloxPlayerLauncher.exe"
PLACELAUNCHER_BASE="https://www.watrbx.wtf/Game/PlaceLauncher.ashx"
AUTH_TICKET="diddy"  # Watrbx's real hardcoded auth ticket

export WINEPREFIX="$HOME/.local/share/watrbx/wine"
export WINEARCH="win32"
export WINEDLLOVERRIDES="d3dx9_35=n,b;wininet=n,b;d3dcompiler_47=n,b;d3d9=n,b;urlmon=n,b"
export WINEDLLPATH=""
export WINEDEBUG="warn+wininet,err+wininet"
export PATH="/usr/local/bin:/usr/bin:/bin"
unset MINGW_PREFIX 2>/dev/null || true

CACHE_DIR="$HOME/.cache/watrbx"
SCRIPT_PATH="$(realpath "$0")"
VERSION_DIR="$WINEPREFIX/drive_c/users/$USER/AppData/Local/Watrbx/Versions"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()    { echo -e "${CYAN}[${REVIVAL_NAME}]${NC} $*"; }
success() { echo -e "${GREEN}[+]${NC} $*"; }
warn()    { echo -e "${YELLOW}[!]${NC} $*"; }
die()     { echo -e "${RED}[X] ERROR:${NC} $*" >&2; exit 1; }
log()     { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"; }

print_banner() {
    echo -e "${CYAN}"
    echo ' +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+'
    echo ' |                                     |'
    echo ' |   __        __    _          _      |'
    echo ' |   \ \      / /_ _| |_ _ __| |__    |'
    echo ' |    \ \ /\ / / _` | __| `__| `_ \   |'
    echo ' |     \ V  V / (_| | |_| |  | |_) |  |'
    echo ' |      \_/\_/ \__,_|\__|_|  |_.__/   |'
    echo ' |                                     |'
    echo ' |        Linux Launcher  v1.0         |'
    echo ' |                                     |'
    echo ' +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+'
    echo -e "${NC}"
}

# ── Detect distro package manager ─────────────────────────
install_deps() {
    if command -v dnf &>/dev/null; then
        sudo dnf install -y wine winetricks cabextract curl python3 mesa-libGL "$@" 2>/dev/null || true
    elif command -v pacman &>/dev/null; then
        sudo pacman -S --noconfirm wine winetricks cabextract curl python3 mesa "$@" 2>/dev/null || true
    elif command -v apt-get &>/dev/null; then
        sudo dpkg --add-architecture i386 2>/dev/null || true
        sudo apt-get update -qq 2>/dev/null || true
        sudo apt-get install -y wine wine32 winetricks cabextract curl python3 libgl1-mesa-glx "$@" 2>/dev/null || true
    elif command -v zypper &>/dev/null; then
        sudo zypper install -y wine winetricks cabextract curl python3 Mesa-libGL1 "$@" 2>/dev/null || true
    else
        warn "Unknown package manager -- please install wine, winetricks, curl, python3 manually."
    fi
}

# ── Cookie helper ─────────────────────────────────────────
write_cookie_helper() {
    cat > "$COOKIE_HELPER" << 'PYEOF'
#!/usr/bin/env python3
import sqlite3, os, glob, sys

profiles = (
    glob.glob(os.path.expanduser("~/.mozilla/firefox/*.default-release")) +
    glob.glob(os.path.expanduser("~/.mozilla/firefox/*.default"))
)

if not profiles:
    sys.exit(1)

try:
    db = profiles[0] + "/cookies.sqlite"
    conn = sqlite3.connect(f"file:{db}?mode=ro&immutable=1", uri=True)
    cur = conn.cursor()
    cur.execute("SELECT name, value FROM moz_cookies WHERE host LIKE '%watrbx%'")
    rows = cur.fetchall()
    conn.close()
    print("; ".join(f"{r[0]}={r[1]}" for r in rows))
except Exception as e:
    print(f"Error: {e}", file=sys.stderr)
    sys.exit(1)
PYEOF
    chmod +x "$COOKIE_HELPER"
}

# ── Helpers ───────────────────────────────────────────────
find_launcher_exe() {
    find "$VERSION_DIR" -name "RobloxPlayerLauncher.exe" 2>/dev/null | head -n1 || true
}

find_terminal() {
    for term in konsole gnome-terminal xfce4-terminal xterm kitty alacritty foot; do
        command -v "$term" &>/dev/null && echo "$term" && return
    done
    echo ""
}

launch_in_terminal() {
    local CMD="$1" TITLE="$2"
    local TERM
    TERM=$(find_terminal)
    case "$TERM" in
        konsole)        konsole --title "$TITLE" -e bash -c "$CMD; echo '--- Exited. Press Enter. ---'; read" & ;;
        gnome-terminal) gnome-terminal --title="$TITLE" -- bash -c "$CMD; echo '--- Exited. Press Enter. ---'; read" & ;;
        xfce4-terminal) xfce4-terminal --title="$TITLE" -e "bash -c \"$CMD; echo '--- Exited. Press Enter. ---'; read\"" & ;;
        xterm)          xterm -title "$TITLE" -e bash -c "$CMD; echo '--- Exited. Press Enter. ---'; read" & ;;
        kitty)          kitty --title "$TITLE" bash -c "$CMD; echo '--- Exited. Press Enter. ---'; read" & ;;
        alacritty)      alacritty --title "$TITLE" -e bash -c "$CMD; echo '--- Exited. Press Enter. ---'; read" & ;;
        foot)           foot --title "$TITLE" bash -c "$CMD; echo '--- Exited. Press Enter. ---'; read" & ;;
        *)              bash -c "$CMD" & ;;
    esac
}

# ── Poll placelauncher ────────────────────────────────────
poll_placelauncher() {
    local URL="$1"
    local FF_COOKIES
    FF_COOKIES=$(python3 "$COOKIE_HELPER" 2>/dev/null || true)

    if [ -n "$FF_COOKIES" ]; then
        log "Got Firefox cookies for auth"
    else
        log "No cookies found, polling unauthenticated"
    fi

    for i in 1 2 3 4 5 6 7 8 9 10; do
        RESULT=$(curl -s --max-time 10 \
            -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win32; x32) AppleWebKit/537.36" \
            ${FF_COOKIES:+-H "Cookie: $FF_COOKIES"} \
            "$URL" 2>/dev/null || true)
        STATUS=$(echo "$RESULT" | python3 -c \
            "import sys,json; print(json.load(sys.stdin).get('status',''))" \
            2>/dev/null || true)
        log "Poll $i -- status: $STATUS"

        if [ "$STATUS" = "2" ]; then
            log "Server ready! Polling joinScriptUrl..."
            JOIN_URL=$(echo "$RESULT" | python3 -c \
                "import sys,json; print(json.load(sys.stdin).get('joinScriptUrl',''))" \
                2>/dev/null || true)
            if [ -n "$JOIN_URL" ] && [ "$JOIN_URL" != "None" ]; then
                log "joinScriptUrl: $JOIN_URL"
                for j in 1 2 3 4 5 6 7 8 9 10; do
                    JOIN_RESULT=$(curl -s --max-time 10 \
                        -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win32; x32) AppleWebKit/537.36" \
                        ${FF_COOKIES:+-H "Cookie: $FF_COOKIES"} \
                        "$JOIN_URL" 2>/dev/null || true)
                    if [ -n "$JOIN_RESULT" ]; then
                        log "Join script ready after $j poll(s)!"
                        return 0
                    fi
                    log "Join script poll $j -- not ready yet"
                    sleep 2
                done
                log "Join script never responded -- launching anyway"
            fi
            return 0
        fi
        sleep 3
    done
    return 1
}

# ── Launch game ───────────────────────────────────────────
launch_game() {
    local URI="$1"

    # Fix missing // after scheme (Firefox strips it)
    if echo "$URI" | grep -qP '^watrbx-player:[^/]'; then
        URI="${URI/watrbx-player:/watrbx-player://}"
        log "Fixed URI: added missing //"
    fi

    log "=== Launching game ==="
    log "URI: $URI"

    rm -f "$LOCKFILE"
    touch "$LOCKFILE"
    trap "rm -f $LOCKFILE" EXIT INT TERM

    write_cookie_helper

    # Kill stale wineserver
    timeout 3 bash -c "WINEPREFIX='$WINEPREFIX' wineserver -k" 2>/dev/null || true
    sleep 0.5

    # Remove bad 64-bit DLLs dropped by updater
    find "$VERSION_DIR" -name "*.dll" 2>/dev/null | while read -r dll; do
        if file "$dll" | grep -q "PE32+"; then
            log "Removing 64-bit DLL: $dll"
            rm -f "$dll"
        fi
    done

    LAUNCHER_EXE=$(find_launcher_exe)
    log "Launcher exe: ${LAUNCHER_EXE:-NOT FOUND}"

    if [ -z "$LAUNCHER_EXE" ]; then
        log "ERROR: Launcher not found"
        command -v notify-send &>/dev/null && \
            notify-send "Watrbx" "Client not installed. Run launcher first." --icon=dialog-error
        exit 1
    fi

    # Poll placelauncher
    PLACELAUNCHER_URL=$(echo "$URI" | grep -oP '(?<=placelauncherurl:)[^+]+' | \
        python3 -c "import sys,urllib.parse; print(urllib.parse.unquote(sys.stdin.read().strip()))" \
        2>/dev/null || true)

    if [ -n "$PLACELAUNCHER_URL" ]; then
        log "Polling placelauncher..."
        if ! poll_placelauncher "$PLACELAUNCHER_URL"; then
            log "Server not ready after polling -- aborting"
            command -v notify-send &>/dev/null && \
                notify-send "Watrbx" "No server available yet. Try again in a moment!" --icon=dialog-warning
            exit 0
        fi
    fi

    # Write DXVK config
    local VERSION_FOLDER
    VERSION_FOLDER=$(dirname "$LAUNCHER_EXE")
    cat > "$VERSION_FOLDER/dxvk.conf" << 'DXVK'
dxvk.presentInterval = 1
d3d9.presentInterval = 1
dxvk.numCompilerThreads = 4
DXVK

    local WINE_CMD="export WINEPREFIX='$WINEPREFIX'; \
export WINEARCH='win32'; \
export WINEDLLPATH=''; \
export WINEDLLOVERRIDES='d3dx9_35=n,b;wininet=n,b;d3dcompiler_47=n,b;d3d9=n,b;urlmon=n,b'; \
export WINEDEBUG='warn+wininet,err+wininet'; \
export PATH='/usr/local/bin:/usr/bin:/bin'; \
echo ''; \
echo ' +----------------------------+'; \
echo ' |  Watrbx -- Game Output     |'; \
echo ' +----------------------------+'; \
echo ''; \
wine '$LAUNCHER_EXE' '$URI' > >(tee '$WINE_LOG' | grep -v 'fixme\|TkG\|winediag\|GetCurrentPackage') 2>&1; echo done"

    local DEBUG_CMD="echo ''; \
echo ' +----------------------------+'; \
echo ' |  Watrbx -- Live Debug      |'; \
echo ' +----------------------------+'; \
echo ''; \
tail -f '$LOG_FILE' '$WINE_LOG' 2>/dev/null | grep -v 'TkG\|winediag\|GetCurrentPackage\|fixme\|Launcher called\|Setup mode\|Args:'"

    log "Launching terminal..."
    launch_in_terminal "$WINE_CMD" "Watrbx"
    sleep 1
    launch_in_terminal "$DEBUG_CMD" "Watrbx Debug"

    command -v notify-send &>/dev/null && \
        notify-send "Watrbx" "Game launching... may take ~30-60 seconds." --icon=dialog-information

    log "Terminal launched."
}

# ══════════════════════════════════════════════════════════
#  --play [PLACE-ID]
# ══════════════════════════════════════════════════════════
if [[ "${1:-}" == "--play" ]]; then
    PLACE_ID="${2:-}"
    [ -z "$PLACE_ID" ] && die "Usage: $SCRIPT_PATH --play [PLACE-ID]"

    print_banner
    info "Joining place ID: $PLACE_ID"
    write_cookie_helper

    PLACELAUNCHER_URL="$PLACELAUNCHER_BASE?request=RequestGame&browserTrackerId=false&placeId=$PLACE_ID&isPartyLeader=false"
    FF_COOKIES=$(python3 "$COOKIE_HELPER" 2>/dev/null || true)

    info "Polling server..."
    SERVER_READY=false
    for i in $(seq 1 10); do
        RESULT=$(curl -s --max-time 10 \
            -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win32; x32) AppleWebKit/537.36" \
            ${FF_COOKIES:+-H "Cookie: $FF_COOKIES"} \
            "$PLACELAUNCHER_URL" 2>/dev/null || true)
        STATUS=$(echo "$RESULT" | python3 -c \
            "import sys,json; print(json.load(sys.stdin).get('status',''))" \
            2>/dev/null || true)
        info "Poll $i -- status: $STATUS"
        if [ "$STATUS" = "2" ]; then
            success "Server ready!"
            SERVER_READY=true
            break
        fi
        sleep 3
    done

    if [ "$SERVER_READY" = "false" ]; then
        warn "No server available for place $PLACE_ID -- try again in a moment."
        exit 1
    fi

    LAUNCH_TIME=$(date +%s%3N)
    ENCODED_URL=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$PLACELAUNCHER_URL'))")
    URI="watrbx-player://1+launchmode:play+gameinfo:${AUTH_TICKET}+launchtime:${LAUNCH_TIME}+placelauncherurl:${ENCODED_URL}+browsertrackerid:false"

    log "Built URI for place $PLACE_ID"
    launch_game "$URI"
    exit 0
fi

# ══════════════════════════════════════════════════════════
#  --debug
# ══════════════════════════════════════════════════════════
if [[ "${1:-}" == "--debug" ]]; then
    print_banner
    echo -e "${BOLD}=== Debug Info ===${NC}"
    echo -e "  Script:      $SCRIPT_PATH"
    echo -e "  WINEPREFIX:  $WINEPREFIX"
    echo -e "  Wine:        $(wine --version 2>/dev/null || echo 'NOT FOUND')"
    echo -e "  Terminal:    $(find_terminal || echo 'none found')"
    echo -e "  GPU:         $(glxinfo 2>/dev/null | grep 'OpenGL renderer' | cut -d: -f2 | xargs || echo 'unknown')"
    echo ""
    echo -e "${BOLD}Launcher exe:${NC}"
    EXE=$(find_launcher_exe)
    [ -z "$EXE" ] && echo -e "  ${RED}NOT FOUND${NC}" || echo -e "  ${GREEN}$EXE${NC}"
    echo ""
    echo -e "${BOLD}Key DLLs:${NC}"
    for dll in d3dx9_35.dll d3dcompiler_47.dll wininet.dll urlmon.dll; do
        F=$(find "$WINEPREFIX/drive_c/windows/system32" -iname "$dll" 2>/dev/null | head -1)
        if [ -n "$F" ]; then
            ARCH=$(file "$F" | grep -o "PE32+\|PE32" | head -1)
            echo -e "  ${GREEN}[OK]${NC} $dll -- $ARCH"
        else
            echo -e "  ${RED}[!!]${NC} $dll MISSING"
        fi
    done
    echo ""
    write_cookie_helper
    echo -e "${BOLD}Firefox cookies:${NC}"
    COOKIES=$(python3 "$COOKIE_HELPER" 2>/dev/null || true)
    if [ -n "$COOKIES" ]; then
        echo "$COOKIES" | tr ';' '\n' | grep -oP '[^=]+(?==)' | while read -r name; do
            echo -e "  ${GREEN}[OK]${NC} $name"
        done
    else
        echo -e "  ${RED}[!!]${NC} No cookies found"
    fi
    echo ""
    echo -e "${BOLD}Recent log:${NC}"
    [ -f "$LOG_FILE" ] && tail -20 "$LOG_FILE" || echo "  No log yet."
    exit 0
fi

# ══════════════════════════════════════════════════════════
#  --fix-firefox
# ══════════════════════════════════════════════════════════
if [[ "${1:-}" == "--fix-firefox" ]]; then
    info "Fixing Firefox watrbx-player:// handler..."
    FF_PROFILE=$(find "$HOME/.mozilla/firefox" -maxdepth 1 \
        \( -name "*.default-release" -o -name "*.default" \) -type d 2>/dev/null | head -n1 || true)
    [ -z "$FF_PROFILE" ] && die "Firefox profile not found."
    HANDLERS="$FF_PROFILE/handlers.json"
    [ ! -f "$HANDLERS" ] && die "handlers.json not found. Open Firefox first, then try again."
    cp "$HANDLERS" "$HANDLERS.bak"
    python3 - "$HANDLERS" << 'PYEOF'
import json, sys
with open(sys.argv[1]) as f:
    data = json.load(f)
if "schemes" not in data:
    data["schemes"] = {}
data["schemes"]["watrbx-player"] = {"action": 4}
with open(sys.argv[1], "w") as f:
    json.dump(data, f, indent=2)
print("Done.")
PYEOF
    success "Firefox fixed! Fully quit Firefox, restart it, then click Play on watrbx.wtf."
    exit 0
fi

# ══════════════════════════════════════════════════════════
#  --clear-logs
# ══════════════════════════════════════════════════════════
if [[ "${1:-}" == "--clear-logs" ]]; then
    > "$LOG_FILE"
    > "$WINE_LOG" 2>/dev/null || true
    success "Logs cleared."
    exit 0
fi

# ══════════════════════════════════════════════════════════
#  --reset
# ══════════════════════════════════════════════════════════
if [[ "${1:-}" == "--reset" ]]; then
    print_banner
    warn "This will delete your Wine prefix and reinstall everything."
    read -rp "  Are you sure? [y/N] " CONFIRM
    [[ "${CONFIRM,,}" != "y" ]] && exit 0
    WINEPREFIX="$WINEPREFIX" wineserver -k 2>/dev/null || true
    rm -rf "$WINEPREFIX"
    rm -f "$CACHE_DIR/$INSTALLER_EXE"
    rm -f "$LOCKFILE"
    success "Reset done. Re-run this script to reinstall."
    exit 0
fi

# ══════════════════════════════════════════════════════════
#  URI HANDLER (called by browser)
# ══════════════════════════════════════════════════════════
if [[ "${1:-}" == watrbx-player://* ]] || \
   ([[ $# -gt 0 ]] && echo "${1:-}" | grep -q "watrbx-player"); then
    launch_game "$1"
    exit 0
fi

# ══════════════════════════════════════════════════════════
#  SETUP / INSTALL
# ══════════════════════════════════════════════════════════

print_banner
log "=== Setup mode ==="

# ── Check Wine ────────────────────────────────────────────
if ! command -v wine &>/dev/null; then
    info "Wine not found. Installing dependencies..."
    install_deps
else
    info "Wine found: $(wine --version 2>/dev/null)"
fi

if [ -z "$(find_terminal)" ]; then
    warn "No terminal emulator found. Installing xterm..."
    install_deps xterm
fi

success "Dependencies ready."

# ── Wine prefix ───────────────────────────────────────────
mkdir -p "$CACHE_DIR"
if [ -f "$WINEPREFIX/system.reg" ]; then
    warn "Existing Wine prefix found."
    read -rp "  Wipe and start fresh? [Y/n] " WIPE
    if [[ "${WIPE,,}" != "n" ]]; then
        WINEPREFIX="$WINEPREFIX" wineserver -k 2>/dev/null || true
        rm -rf "$WINEPREFIX"
        success "Old prefix removed."
    fi
fi

info "Initialising 32-bit Wine prefix..."
mkdir -p "$WINEPREFIX"
WINEPREFIX="$WINEPREFIX" wineserver -k 2>/dev/null || true
sleep 1
WINEPREFIX="$WINEPREFIX" WINEARCH="win32" wineboot --init 2>/dev/null
success "Wine prefix ready."

# ── Clean registry PATH ───────────────────────────────────
info "Cleaning registry PATH..."
WINEPREFIX="$WINEPREFIX" wine reg add \
    "HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment" \
    /v Path /t REG_EXPAND_SZ \
    /d "C:\\windows\\system32;C:\\windows;C:\\windows\\system32\\wbem" \
    /f 2>/dev/null || true

# ── Internet settings ─────────────────────────────────────
info "Configuring internet settings..."
for reg_entry in \
    "WarnOnBadCertRecving:0" \
    "WarnOnZoneCrossing:0" \
    "ReceiveTimeout:120000" \
    "ConnectTimeout:60000"; do
    KEY="${reg_entry%%:*}"
    VAL="${reg_entry##*:}"
    WINEPREFIX="$WINEPREFIX" wine reg add \
        "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Internet Settings" \
        /v "$KEY" /t REG_DWORD /d "$VAL" /f 2>/dev/null || true
done

# ── Runtimes ──────────────────────────────────────────────
info "Installing DirectX 9..."
WINEPREFIX="$WINEPREFIX" winetricks -q d3dx9 2>/dev/null || warn "d3dx9 had errors."
info "Installing d3dcompiler_47..."
WINEPREFIX="$WINEPREFIX" winetricks -q d3dcompiler_47 2>/dev/null || warn "d3dcompiler_47 had errors."
info "Installing Visual C++ runtimes..."
WINEPREFIX="$WINEPREFIX" winetricks -q vcrun2012 vcrun2015 2>/dev/null || warn "vcrun had errors."
info "Installing native wininet + urlmon..."
WINEPREFIX="$WINEPREFIX" winetricks -q wininet 2>/dev/null || warn "wininet had errors."
info "Installing DXVK..."
WINEPREFIX="$WINEPREFIX" winetricks -q dxvk 2>/dev/null || warn "dxvk had errors."
info "Installing root certificates..."
WINEPREFIX="$WINEPREFIX" winetricks -q certs 2>/dev/null || warn "certs had errors."
success "Runtimes installed."

# ── DLL overrides ─────────────────────────────────────────
info "Registering DLL overrides..."
for dll in d3dx9_35 d3dcompiler_47 msvcp110 msvcr110 wininet urlmon d3d9; do
    WINEPREFIX="$WINEPREFIX" wine reg add \
        "HKEY_CURRENT_USER\Software\Wine\DllOverrides" \
        /v "$dll" /t REG_SZ /d "native,builtin" /f 2>/dev/null || true
done
success "DLL overrides applied."

# ── Download & run installer ──────────────────────────────
INSTALLER_PATH="$CACHE_DIR/$INSTALLER_EXE"
if [ ! -f "$INSTALLER_PATH" ]; then
    info "Downloading Watrbx installer..."
    curl -L --progress-bar -o "$INSTALLER_PATH" "$INSTALLER_URL" || die "Download failed."
    success "Downloaded."
else
    read -rp "  Installer cached. Re-download? [y/N] " R
    [[ "${R,,}" == "y" ]] && curl -L --progress-bar -o "$INSTALLER_PATH" "$INSTALLER_URL"
fi

info "Running Watrbx installer (follow the Windows dialog)..."
WINEPREFIX="$WINEPREFIX" WINEDLLOVERRIDES="wininet=n,b;urlmon=n,b" wine "$INSTALLER_PATH" 2>/dev/null
sleep 3

# ── Remove bad 64-bit DLLs ────────────────────────────────
info "Removing any 64-bit DLLs (incompatible with win32 prefix)..."
find "$WINEPREFIX/drive_c" -path "*/Watrbx/*" -name "*.dll" 2>/dev/null | while read -r dll; do
    if file "$dll" | grep -q "PE32+"; then
        warn "Removing 64-bit: $dll"
        rm -f "$dll"
    fi
done
success "DLL check done."

# ── Windows version ───────────────────────────────────────
info "Setting Windows version to 7..."
WINEPREFIX="$WINEPREFIX" wine reg add \
    "HKEY_LOCAL_MACHINE\Software\Microsoft\Windows NT\CurrentVersion" \
    /v CurrentVersion /t REG_SZ /d "6.1" /f 2>/dev/null || true

# ── URI handler ───────────────────────────────────────────
info "Registering watrbx-player:// URI handler..."
chmod +x "$SCRIPT_PATH"
DESKTOP_DIR="$HOME/.local/share/applications"
mkdir -p "$DESKTOP_DIR"

cat > "$DESKTOP_DIR/watrbx-uri-handler.desktop" << EOF
[Desktop Entry]
Name=Watrbx URI Handler
Exec=${SCRIPT_PATH} %u
Type=Application
NoDisplay=true
MimeType=x-scheme-handler/watrbx-player;
EOF

xdg-mime default watrbx-uri-handler.desktop x-scheme-handler/watrbx-player 2>/dev/null || true
update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true

cat > "$DESKTOP_DIR/watrbx.desktop" << EOF
[Desktop Entry]
Name=Watrbx
Comment=2016 Roblox Revival
Exec=${SCRIPT_PATH}
Type=Application
Categories=Game;
EOF
update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true
success "URI handler registered."

# ── Fix Firefox ───────────────────────────────────────────
FF_PROFILE=$(find "$HOME/.mozilla/firefox" -maxdepth 1 \
    \( -name "*.default-release" -o -name "*.default" \) -type d 2>/dev/null | head -n1 || true)
if [ -n "$FF_PROFILE" ] && [ -f "$FF_PROFILE/handlers.json" ]; then
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
    success "Firefox handler fixed."
else
    warn "Firefox profile not found -- run '${SCRIPT_PATH} --fix-firefox' after opening Firefox."
fi

# ── KDE autostart (optional) ──────────────────────────────
if [ -d "$HOME/.config/autostart" ]; then
    cat > "$HOME/.config/autostart/watrbx-wineserver.desktop" << EOF
[Desktop Entry]
Name=Watrbx Wineserver
Exec=bash -c 'WINEPREFIX=$WINEPREFIX wineserver -f'
Type=Application
X-KDE-autostart-phase=1
EOF
    success "KDE autostart configured."
fi

# ── Done ──────────────────────────────────────────────────
LAUNCHER_EXE=$(find_launcher_exe)
echo ""
echo -e "${BOLD}  +---------------------------------------+${NC}"
echo -e "${BOLD}  |        Setup Complete!                |${NC}"
echo -e "${BOLD}  +---------------------------------------+${NC}"
echo ""
if [ -z "${LAUNCHER_EXE:-}" ]; then
    warn "RobloxPlayerLauncher.exe not found."
    warn "The installer may still be running, or check:"
    warn "  $VERSION_DIR"
else
    success "Client ready:"
    echo    "  $LAUNCHER_EXE"
fi
echo ""
echo -e " ${BOLD}To play via browser:${NC}"
echo    "  1. Fully quit Firefox"
echo -e "  2. Run: ${CYAN}${SCRIPT_PATH} --fix-firefox${NC}"
echo    "  3. Restart Firefox -> go to watrbx.wtf -> click Play"
echo ""
echo -e " ${BOLD}To play via terminal:${NC}"
echo -e "  ${CYAN}${SCRIPT_PATH} --play [PLACE-ID]${NC}"
echo ""
echo -e " ${BOLD}Other commands:${NC}"
echo -e "  ${CYAN}--debug${NC}        show debug info"
echo -e "  ${CYAN}--fix-firefox${NC}  re-fix Firefox URI handler"
echo -e "  ${CYAN}--clear-logs${NC}   clear log files"
echo -e "  ${CYAN}--reset${NC}        full reinstall"
echo ""
echo -e " ${BOLD}Log file:${NC} ${LOG_FILE}"
echo ""
