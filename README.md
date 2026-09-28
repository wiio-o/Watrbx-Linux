
<img width="1600" height="800" alt="watree" src="https://github.com/user-attachments/assets/3dc84b64-415c-45e2-bda6-643e718513cb" />

Watrbx Linux Installer

A lightweight Linux installer for the Watrbx runtime using Wine.

This tool sets up a local Wine prefix, installs the Watrbx player, and
integrates a custom protocol handler for browser-based launching.

(OUTDATED DUE TO WATRBX DYING OUT OF NO WHERE. ON JUNE, and is best instead for editing the code for any other revival!)

COMMANDS

- ./watrbx-launcher.sh --debug | Displays Debug info
- ./watrbx-launcher.sh --update | Updates the Installer
- ./watrbx-launcher.sh --uninstall | Uninstalls the launcher and .desktop files
- ./watrbx-launcher.sh | Installs The launcher

FEATURES

-   Installs Watrbx into an isolated Wine prefix
-   Automatically configures desktop integration
-   Adds custom watrbx-player:// protocol handler
-   Attempts Firefox handler registration (user-level only)
-   Simple CLI-based installer with minimal dependencies

REQUIREMENTS

-   wine (Staging recommended)
-   curl
-   python3
-   firefox
-   xdg-utils

INSTALLATION

chmod +x install.sh ./install.sh

WHAT IT DOES

-   Creates a Wine prefix in: ~/.local/share/watrbx/wine

-   Downloads and runs the Watrbx installer inside Wine

-   Registers a desktop entry for launching the player

-   Adds custom protocol handler: watrbx-player://

-   Attempts Firefox configuration for handling the protocol

-   Updates The Watrbx Player inside Wine

-   Creates a Log File In ~/.local/share/watrbx/installer.log

NOTES

-   Modifies user-level Firefox configuration (handlers.json)
-   Wine applications are contained in the local prefix
-   No system-wide changes outside desktop integration files

DISCLAIMER

This project is not affiliated with or endorsed by any existing game
platforms or companies. All trademarks belong to their respective
owners.
