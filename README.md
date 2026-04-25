Watrbx Linux Launcher

<img width="1600" height="800" alt="watree" src="https://github.com/user-attachments/assets/92945cde-1e14-4e84-913c-55d720d7d6b0" />

A simple Linux launcher for Watrbx, a 2016 Roblox revival that runs through Wine.
It lets you join games directly from your browser or from the terminal on most major Linux distros.

Requirements

- Linux (Fedora, Arch, Ubuntu, Debian, openSUSE, or similar)
- Firefox (recommended for browser joining)
- wine
- winetricks
- curl
- python3

Do not worry if some of these are missing. The setup script installs what it can automatically.

Installation

chmod +x watrbx-launcher.sh
./watrbx-launcher.sh

During setup, the launcher will:

- Detect your distro and install needed packages
- Create a 32-bit Wine prefix
- Install DirectX 9, DXVK, Visual C++ runtimes, and required DLL overrides
- Download and install Watrbx
- Register the watrbx-player:// protocol handler
- Patch Firefox so the Play button works properly

Playing

Browser method (recommended)

1. Run:
   ./watrbx-launcher.sh --fix-firefox

2. Fully close Firefox and reopen it

3. Visit watrbx.wtf, choose a game, and press Play

Terminal method

./watrbx-launcher.sh --play [PLACE-ID]

Example:

./watrbx-launcher.sh --play 958

Commands

./watrbx-launcher.sh
    Run setup or install launcher components

./watrbx-launcher.sh --play [ID]
    Join a game by place ID

./watrbx-launcher.sh --debug
    Show debug info and DLL status

./watrbx-launcher.sh --fix-firefox
    Re-apply Firefox protocol patch

./watrbx-launcher.sh --clear-logs
    Remove launcher and Wine logs

./watrbx-launcher.sh --reset
    Delete Wine prefix and reinstall everything

How it works

- Clicking Play in Firefox opens a watrbx-player:// link
- The launcher catches the link and fixes Firefox formatting issues
- It checks the PlaceLauncher API until the server is ready
- It verifies the join script URL
- Wine starts RobloxPlayerLauncher.exe with the correct launch data
- Two terminal windows open:
  one for game output, one for live debug logs

Tested on

- Fedora 43 with KDE Plasma
- Wine 9.21 TkG Staging NTsync
- NVIDIA GTX 1060 using DXVK and Vulkan
- AMD Radeon using RADV

It may also work on other systems, but results can vary.

Known Issues

- Long loading times

  Some Watrbx servers can take 30 to 120+ seconds to respond.
  This is a server-side issue.

- Join failures

  Sometimes the server fails to send the join script.
  Close the game and try again.

- Roblox crash popup

  This may appear while loading.
  Usually caused by Watrbx itself, not the launcher.

Notes

- The launcher uses "diddy" as the auth ticket.
  This is the token currently hardcoded by Watrbx.

- Any 64-bit DLLs added by the updater are removed automatically.
  Watrbx needs a 32-bit Wine prefix for best compatibility.

- Logs are stored at:

  ~/.local/share/watrbx/launcher.log

Made with too much debugging, a hidden Easter egg, and a lot of patience.
