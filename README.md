# AppImage Manager

A full-featured Bash utility for installing, managing, and removing AppImages on **Debian/GNOME** (and compatible distros). It moves AppImages to `~/Applications`, extracts their icons, registers them in the GNOME app grid, and tracks everything in a local registry — so you can manage apps with simple commands instead of fiddling with `.desktop` files manually.

## Quick Install (Recommended)

Install with a single command. This will download the script to `~/.local/bin` and make it globally available as `appimage`.

```bash
bash <(curl -sSL https://raw.githubusercontent.com/DD00031/appimage-manager/refs/heads/main/install.sh)
```

**Usage:** Once installed, simply open your terminal and type:

```bash
appimage --help
```

## Manual Installation

If you prefer to install manually:

1. Clone the repository:

```bash
git clone https://github.com/DD00031/appimage-manager.git
cd appimage-manager
```

2. Make the script executable:

```bash
chmod +x appimage.sh
```

3. Run it locally:

```bash
./appimage.sh --help
```

4. (Optional) Install globally using the built-in self-install command:

```bash
./appimage.sh --self-install
source ~/.bashrc
```

## Requirements

* **OS:** Linux (Debian/Ubuntu/GNOME recommended)
* **Desktop:** GNOME (for app grid integration)
* **Dependencies:** `desktop-file-utils`, `xdg-utils`
  * Install with: `sudo apt install desktop-file-utils xdg-utils`

## Commands

| Command | Description |
|---|---|
| `appimage --install <file.AppImage> [Name]` | Install an AppImage and register it in the app grid |
| `appimage --uninstall <Name>` | Remove an installed app (with confirmation prompt) |
| `appimage --update <Name> <new-file.AppImage>` | Replace an existing install with a newer version |
| `appimage --run <Name> [args…]` | Launch an installed app from the terminal |
| `appimage --list` | List all apps managed by this tool |
| `appimage --info <Name>` | Show paths, size, and `.desktop` details for an app |
| `appimage --self-install` | Copy this script to `~/.local/bin/appimage` |
| `appimage --self-uninstall` | Remove the tool (optionally remove all managed AppImages too) |

## How it works

1. **Install** — The AppImage is copied to `~/Applications/<Name>/`, marked executable, and its icon is extracted directly from the AppImage (no FUSE/mounting needed).
2. **Register** — A `.desktop` entry is written to `~/.local/share/applications/`, which makes the app appear in the GNOME Activities app grid (press Super key).
3. **Track** — A local registry at `~/.local/share/appimage-manager/registry` keeps track of installed apps so `--list`, `--uninstall`, and `--update` always know what's managed.
4. **Launch** — The app is launched automatically after install.

## License

appimage-manager is available under the GPL-3.0 license.

## Disclaimer

This project was built with the help of Claude as a personal utility for Debian/GNOME. Feel free to open an issue or submit a pull request!
