
<img width="1600" height="800" alt="watree" src="https://github.com/user-attachments/assets/3dc84b64-415c-45e2-bda6-643e718513cb" />

Watrbx Linux Launcher (Experimental)

A simple Linux launcher for Watrbx, a 2016 Roblox revival running through Wine.

It lets you join games from your browser or terminal on most Linux systems.

Not perfect. Just functional.

------------------------------------------------------------

Requirements

- Linux (Fedora / Arch / Ubuntu / Debian / openSUSE or similar)
- wine
- winetricks
- curl
- python3
- Firefox (recommended)

If something is missing, the setup script will try to install it.

------------------------------------------------------------

Install

chmod +x watrbx-launcher.sh
./watrbx-launcher.sh

The script will:
- install dependencies
- create a 32-bit Wine prefix
- install DirectX / VC++ / DXVK runtimes
- download Watrbx
- register browser handler
- patch Firefox (if available)

------------------------------------------------------------

Play

Browser method (recommended)

First:
1. Close Firefox completely

Then:
1. ./watrbx-launcher.sh --fix-firefox
3. Reopen it
4. Go to watrbx.wtf
5. Press Play

Terminal method

./watrbx-launcher.sh --play <PLACE-ID>

Example:
./watrbx-launcher.sh --play 958

------------------------------------------------------------

Commands

--play [id]        Join a game by place ID
--debug            Show debug info
--fix-firefox      Fix watrbx-player:// handler
--clear-logs       Clear logs
--reset            Wipe Wine prefix and reinstall

------------------------------------------------------------

How it works

1. Browser or terminal sends a watrbx-player:// link
2. Launcher catches it
3. Contacts Watrbx PlaceLauncher API
4. Waits for server readiness
5. Fetches join script
6. Launches Wine + Roblox client
7. Game starts (hopefully)

------------------------------------------------------------

Known issues

Join failures:
Sometimes joining works, sometimes it doesn't.
Caused by backend timing and server response inconsistency.

Crash popup:
A random "serious error" popup may appear.
It is ignored and does not affect gameplay.

------------------------------------------------------------

Tested on
- Fedora 43 KDE
- Wine 9.x staging
- NVIDIA GTX 1060 (DXVK)
- AMD RADV Vulkan

Works elsewhere too, probably.

------------------------------------------------------------

Logs
~/.local/share/watrbx/launcher.log

------------------------------------------------------------

Notes
- Uses "diddy" as auth ticket (Watrbx-defined)
- Requires 32-bit Wine prefix
- Some DLL cleanup happens automatically
- Yes, there are hacks. Yes, it works.

------------------------------------------------------------

Made with:
- too much bash
- too much Wine debugging
- stubbornness
