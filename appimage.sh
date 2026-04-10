#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════╗
# ║  appimage — AppImage manager for Debian/GNOME                   ║
# ║                                                                  ║
# ║  Usage:                                                          ║
# ║    appimage --install   <file.AppImage> [Name]                   ║
# ║    appimage --uninstall <Name>                                   ║
# ║    appimage --run       <Name> [args…]                           ║
# ║    appimage --list                                               ║
# ║    appimage --info      <Name>                                   ║
# ║    appimage --update    <Name> <new-file.AppImage>               ║
# ║    appimage --self-install                                       ║
# ║    appimage --self-uninstall                                     ║
# ╚══════════════════════════════════════════════════════════════════╝

set -euo pipefail

# ── Colours ────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
die()     { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }
header()  { echo -e "\n${BOLD}${CYAN}$*${NC}"; }

# ── Constants ──────────────────────────────────────────────────────
APPS_DIR="$HOME/Applications"
ICON_DIR="$HOME/.local/share/icons/hicolor/256x256/apps"
DESKTOP_DIR="$HOME/.local/share/applications"
REGISTRY="$HOME/.local/share/appimage-manager/registry"   # name→id map

# ── Helpers ────────────────────────────────────────────────────────
to_id() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g'
}

ensure_registry() {
    mkdir -p "$(dirname "$REGISTRY")"
    touch "$REGISTRY"
}

registry_add() {       # registry_add <APP_NAME> <APP_ID>
    ensure_registry
    # Remove any existing entry for this name first
    sed -i "/^${1}=/d" "$REGISTRY" 2>/dev/null || true
    echo "${1}=${2}" >> "$REGISTRY"
}

registry_remove() {    # registry_remove <APP_NAME>
    ensure_registry
    sed -i "/^${1}=/d" "$REGISTRY" 2>/dev/null || true
}

registry_id() {        # registry_id <APP_NAME> → prints APP_ID or empty
    ensure_registry
    grep "^${1}=" "$REGISTRY" 2>/dev/null | cut -d= -f2 || true
}

refresh_desktop() {
    if command -v update-desktop-database &>/dev/null; then
        update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true
    fi
}

# ── Command: help ──────────────────────────────────────────────────
cmd_help() {
    echo -e "
${BOLD}appimage${NC} — AppImage manager for Debian/GNOME

${BOLD}USAGE${NC}
  appimage ${CYAN}--install${NC}   <file.AppImage> [Name]   Install an AppImage
  appimage ${CYAN}--uninstall${NC} <Name>                   Remove an installed app
  appimage ${CYAN}--update${NC}    <Name> <file.AppImage>   Replace with a newer version
  appimage ${CYAN}--run${NC}       <Name> [args…]           Launch an installed app
  appimage ${CYAN}--list${NC}                               List all managed apps
  appimage ${CYAN}--info${NC}      <Name>                   Show details for an app
  appimage ${CYAN}--self-install${NC}                       Copy this script to ~/.local/bin
  appimage ${CYAN}--self-uninstall${NC}                     Remove this script from ~/.local/bin

${BOLD}EXAMPLES${NC}
  appimage --install ~/Downloads/Obsidian.AppImage
  appimage --install ~/Downloads/Obsidian.AppImage \"Obsidian\"
  appimage --uninstall Obsidian
  appimage --update Obsidian ~/Downloads/Obsidian-1.5.AppImage
  appimage --run Obsidian
  appimage --list
  appimage --info Obsidian
  appimage --self-uninstall
"
}

# ── Command: self-install ──────────────────────────────────────────
cmd_self_install() {
    local target="$HOME/.local/bin/appimage"
    mkdir -p "$HOME/.local/bin"
    cp "$(realpath "$0")" "$target"
    chmod +x "$target"
    success "Installed to $target"

    # Check PATH
    if ! echo "$PATH" | grep -q "$HOME/.local/bin"; then
        warn "~/.local/bin is not in your PATH."
        echo "  Add this to your ~/.bashrc or ~/.zshrc:"
        echo -e "  ${CYAN}export PATH=\"\$HOME/.local/bin:\$PATH\"${NC}"
        echo "  Then run: source ~/.bashrc"
    else
        success "~/.local/bin is already in your PATH — you're all set!"
        echo "  Run 'appimage --help' from anywhere."
    fi
}

# ── Command: self-uninstall ───────────────────────────────────────
cmd_self_uninstall() {
    local target="$HOME/.local/bin/appimage"

    header "Uninstall appimage manager"

    # ── Show managed apps and ask whether to remove them ─────────
    ensure_registry
    local app_count=0
    [[ -s "$REGISTRY" ]] && app_count="$(grep -c '.' "$REGISTRY" 2>/dev/null || echo 0)"

    local remove_apps="n"
    if [[ "$app_count" -gt 0 ]]; then
        echo -e "  You have ${BOLD}${app_count}${NC} app(s) installed via appimage:\n"
        while IFS='=' read -r name id; do
            [[ -z "$name" ]] && continue
            local bin="$APPS_DIR/${name}/${name}.AppImage"
            local size=""
            [[ -f "$bin" ]] && size=" ($(du -sh "$bin" 2>/dev/null | cut -f1))"
            echo -e "    ${YELLOW}•${NC} ${name}${size}"
        done < "$REGISTRY"
        echo ""
        read -r -p "  Remove all installed AppImages too? [y/N] " remove_apps
    else
        echo "  No managed AppImages found."
    fi

    # ── Confirm removal of the tool itself ────────────────────────
    echo ""
    read -r -p "  Remove the appimage utility from ~/.local/bin? [y/N] " remove_tool
    [[ "$remove_tool" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }

    # ── Remove apps if requested ──────────────────────────────────
    if [[ "$remove_apps" =~ ^[Yy]$ ]]; then
        echo ""
        info "Removing all managed AppImages…"
        while IFS='=' read -r name id; do
            [[ -z "$name" ]] && continue
            local app_dir="$APPS_DIR/${name}"
            local icon="$ICON_DIR/${id}.png"
            local desktop="$DESKTOP_DIR/${id}.desktop"
            [[ -d "$app_dir" ]] && { rm -rf "$app_dir"; success "Removed $app_dir"; }
            [[ -f "$icon"    ]] && { rm -f  "$icon";    success "Removed icon for $name"; }
            [[ -f "$desktop" ]] && { rm -f  "$desktop"; success "Removed .desktop for $name"; }
        done < "$REGISTRY"
        refresh_desktop
        success "All managed AppImages removed."
    else
        warn "Keeping installed AppImages. Their entries remain in the app grid."
    fi

    # ── Remove registry & tool ────────────────────────────────────
    echo ""
    info "Removing registry…"
    rm -f "$REGISTRY"
    rmdir "$(dirname "$REGISTRY")" 2>/dev/null || true
    success "Registry removed."

    if [[ -f "$target" ]]; then
        rm -f "$target"
        success "Removed $target"
    else
        warn "appimage not found at $target — may already be removed."
    fi

    echo ""
    success "appimage manager has been uninstalled."
    echo ""
}

# ── Command: install ──────────────────────────────────────────────
cmd_install() {
    local src="${1:-}"
    [[ -z "$src" ]]   && die "Usage: appimage --install <file.AppImage> [Name]"
    [[ -f "$src" ]]   || die "File not found: $src"

    local base
    base="$(basename "$src" .AppImage)"
    base="$(basename "$base" .appimage)"
    local APP_NAME="${2:-$base}"
    local APP_ID;  APP_ID="$(to_id "$APP_NAME")"

    local APP_DIR="$APPS_DIR/${APP_NAME}"
    local APP_BIN="${APP_DIR}/${APP_NAME}.AppImage"
    local ICON_PATH="${ICON_DIR}/${APP_ID}.png"
    local DESKTOP_FILE="${DESKTOP_DIR}/${APP_ID}.desktop"
    local EXTRACT_TMP; EXTRACT_TMP="$(mktemp -d)"

    # Already installed?
    if [[ -f "$DESKTOP_FILE" ]]; then
        warn "'${APP_NAME}' appears to already be installed."
        read -r -p "      Overwrite? [y/N] " confirm
        [[ "$confirm" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }
    fi

    header "Installing '${APP_NAME}'"
    echo -e "  Source  : $src"
    echo -e "  Target  : $APP_BIN"

    # 1. Copy AppImage
    info "Copying AppImage…"
    mkdir -p "$APP_DIR"
    cp "$src" "$APP_BIN"
    chmod +x "$APP_BIN"
    success "AppImage ready at $APP_BIN"

    # 2. Extract icon + bundled .desktop
    info "Extracting resources from AppImage…"
    mkdir -p "$ICON_DIR" "$EXTRACT_TMP"
    local SQUASHFS_ROOT="${EXTRACT_TMP}/squashfs-root"
    (
        cd "$EXTRACT_TMP"
        "$APP_BIN" --appimage-extract '*.png'     2>/dev/null || true
        "$APP_BIN" --appimage-extract '*.svg'     2>/dev/null || true
        "$APP_BIN" --appimage-extract '*.desktop' 2>/dev/null || true
    ) || true

    # Best icon: prefer high-res PNG
    local ICON_CANDIDATE
    ICON_CANDIDATE="$(
        { find "$SQUASHFS_ROOT" -type f \( -name '*.png' -o -name '*.svg' \) 2>/dev/null \
            | grep -i '256\|512\|128\|scalable\|hicolor' \
            | head -1
          find "$SQUASHFS_ROOT" -maxdepth 4 -type f -name '*.png' 2>/dev/null \
            | head -1
        } | head -1
    )"

    if [[ -n "$ICON_CANDIDATE" && -f "$ICON_CANDIDATE" ]]; then
        cp "$ICON_CANDIDATE" "$ICON_PATH"
        success "Icon extracted → $ICON_PATH"
    else
        warn "Could not extract icon; using system fallback."
        cp /usr/share/pixmaps/debian-logo.png "$ICON_PATH" 2>/dev/null || \
        cp /usr/share/icons/hicolor/48x48/apps/xterm-color.png "$ICON_PATH" 2>/dev/null || true
    fi

    # Pull categories/comment from bundled .desktop if present
    local BUNDLED_DESKTOP CATEGORIES COMMENT
    BUNDLED_DESKTOP="$(find "$SQUASHFS_ROOT" -maxdepth 2 -name '*.desktop' 2>/dev/null | head -1)"
    CATEGORIES="Utility;"
    COMMENT=""
    if [[ -n "$BUNDLED_DESKTOP" && -f "$BUNDLED_DESKTOP" ]]; then
        local cats cmt
        cats="$(grep -i '^Categories=' "$BUNDLED_DESKTOP" | head -1 | cut -d= -f2 || true)"
        cmt="$( grep -i '^Comment='    "$BUNDLED_DESKTOP" | head -1 | cut -d= -f2 || true)"
        [[ -n "$cats" ]] && CATEGORIES="$cats"
        [[ -n "$cmt"  ]] && COMMENT="$cmt"
    fi

    rm -rf "$EXTRACT_TMP"

    # 3. Write .desktop
    info "Writing .desktop entry…"
    mkdir -p "$DESKTOP_DIR"
    cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=${APP_NAME}
Comment=${COMMENT:-Run ${APP_NAME}}
Exec=${APP_BIN} %U
Icon=${ICON_PATH}
Terminal=false
Categories=${CATEGORIES}
StartupNotify=true
StartupWMClass=${APP_ID}
X-AppImage-Integrate=true
X-AppImage-Manager=appimage-cli
EOF
    chmod 644 "$DESKTOP_FILE"
    success ".desktop entry written."

    # 4. Register with XDG
    info "Registering with desktop…"
    refresh_desktop
    if command -v xdg-icon-resource &>/dev/null && [[ -f "$ICON_PATH" ]]; then
        xdg-icon-resource install --novendor --context apps --size 256 \
            "$ICON_PATH" "$APP_ID" 2>/dev/null || true
    fi
    success "Registered in app grid."

    # 5. Save to registry
    registry_add "$APP_NAME" "$APP_ID"

    # 6. Launch
    echo ""
    info "Launching ${APP_NAME}…"
    nohup "$APP_BIN" &>/dev/null &
    disown

    echo ""
    success "${BOLD}${APP_NAME} installed successfully!${NC}"
    echo -e "  AppImage : ${BLUE}${APP_BIN}${NC}"
    echo -e "  Icon     : ${BLUE}${ICON_PATH}${NC}"
    echo -e "  Desktop  : ${BLUE}${DESKTOP_FILE}${NC}"
    echo ""
}

# ── Command: uninstall ────────────────────────────────────────────
cmd_uninstall() {
    local APP_NAME="${1:-}"
    [[ -z "$APP_NAME" ]] && die "Usage: appimage --uninstall <Name>"

    local APP_ID; APP_ID="$(registry_id "$APP_NAME")"
    # Fall back to deriving the ID if not in registry (e.g. manually installed)
    [[ -z "$APP_ID" ]] && APP_ID="$(to_id "$APP_NAME")"

    local APP_DIR="$APPS_DIR/${APP_NAME}"
    local ICON_PATH="${ICON_DIR}/${APP_ID}.png"
    local DESKTOP_FILE="${DESKTOP_DIR}/${APP_ID}.desktop"

    # Sanity check — make sure at least one managed file exists
    if [[ ! -d "$APP_DIR" && ! -f "$DESKTOP_FILE" ]]; then
        die "'${APP_NAME}' does not appear to be installed (checked $APP_DIR and $DESKTOP_FILE)."
    fi

    header "Uninstalling '${APP_NAME}'"
    read -r -p "  This will delete the AppImage, icon and .desktop entry. Continue? [y/N] " confirm
    [[ "$confirm" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }

    [[ -d "$APP_DIR"      ]] && { rm -rf "$APP_DIR";      success "Removed $APP_DIR"; }
    [[ -f "$ICON_PATH"    ]] && { rm -f  "$ICON_PATH";    success "Removed icon"; }
    [[ -f "$DESKTOP_FILE" ]] && { rm -f  "$DESKTOP_FILE"; success "Removed .desktop entry"; }

    refresh_desktop
    registry_remove "$APP_NAME"

    echo ""
    success "'${APP_NAME}' has been uninstalled."
    echo ""
}

# ── Command: update ───────────────────────────────────────────────
cmd_update() {
    local APP_NAME="${1:-}" NEW_SRC="${2:-}"
    [[ -z "$APP_NAME" || -z "$NEW_SRC" ]] && die "Usage: appimage --update <Name> <new-file.AppImage>"
    [[ -f "$NEW_SRC" ]] || die "File not found: $NEW_SRC"

    local APP_ID; APP_ID="$(registry_id "$APP_NAME")"
    [[ -z "$APP_ID" ]] && APP_ID="$(to_id "$APP_NAME")"

    local APP_DIR="$APPS_DIR/${APP_NAME}"
    local APP_BIN="${APP_DIR}/${APP_NAME}.AppImage"

    [[ -d "$APP_DIR" ]] || die "'${APP_NAME}' is not installed."

    header "Updating '${APP_NAME}'"
    info "Replacing AppImage…"

    # Backup old binary briefly in case something goes wrong
    local BACKUP="${APP_BIN}.bak"
    cp "$APP_BIN" "$BACKUP"

    cp "$NEW_SRC" "$APP_BIN"
    chmod +x "$APP_BIN"

    # Re-extract icon (new version may have changed it)
    info "Re-extracting icon…"
    local EXTRACT_TMP; EXTRACT_TMP="$(mktemp -d)"
    local SQUASHFS_ROOT="${EXTRACT_TMP}/squashfs-root"
    (
        cd "$EXTRACT_TMP"
        "$APP_BIN" --appimage-extract '*.png' 2>/dev/null || true
        "$APP_BIN" --appimage-extract '*.svg' 2>/dev/null || true
    ) || true

    local ICON_PATH="${ICON_DIR}/${APP_ID}.png"
    local ICON_CANDIDATE
    ICON_CANDIDATE="$(
        { find "$SQUASHFS_ROOT" -type f \( -name '*.png' -o -name '*.svg' \) 2>/dev/null \
            | grep -i '256\|512\|128\|scalable\|hicolor' | head -1
          find "$SQUASHFS_ROOT" -maxdepth 4 -type f -name '*.png' 2>/dev/null | head -1
        } | head -1
    )"
    [[ -n "$ICON_CANDIDATE" && -f "$ICON_CANDIDATE" ]] && cp "$ICON_CANDIDATE" "$ICON_PATH"
    rm -rf "$EXTRACT_TMP" "$BACKUP"

    refresh_desktop
    echo ""
    success "'${APP_NAME}' updated successfully."
    echo ""
}

# ── Command: run ──────────────────────────────────────────────────
cmd_run() {
    local APP_NAME="${1:-}"
    [[ -z "$APP_NAME" ]] && die "Usage: appimage --run <Name> [args…]"
    shift

    local APP_BIN="$APPS_DIR/${APP_NAME}/${APP_NAME}.AppImage"
    [[ -f "$APP_BIN" ]] || die "'${APP_NAME}' not found at $APP_BIN"
    [[ -x "$APP_BIN" ]] || chmod +x "$APP_BIN"

    info "Launching ${APP_NAME}…"
    nohup "$APP_BIN" "$@" &>/dev/null &
    disown
    success "${APP_NAME} launched."
}

# ── Command: list ─────────────────────────────────────────────────
cmd_list() {
    ensure_registry
    header "Installed AppImages"

    if [[ ! -s "$REGISTRY" ]]; then
        # Fall back: scan ~/Applications for any .AppImage
        local found=0
        while IFS= read -r -d '' appimage; do
            local name; name="$(basename "$(dirname "$appimage")")"
            echo -e "  ${GREEN}•${NC} ${BOLD}${name}${NC}  ${BLUE}(${appimage})${NC}"
            found=1
        done < <(find "$APPS_DIR" -maxdepth 2 -name '*.AppImage' -print0 2>/dev/null)
        [[ $found -eq 0 ]] && echo "  No apps installed yet." || true
        echo ""
        return
    fi

    local count=0
    while IFS='=' read -r name id; do
        [[ -z "$name" ]] && continue
        local bin="$APPS_DIR/${name}/${name}.AppImage"
        local desktop="$DESKTOP_DIR/${id}.desktop"
        local size=""
        [[ -f "$bin" ]] && size=" ($(du -sh "$bin" 2>/dev/null | cut -f1))"
        local status="${GREEN}✔${NC}"
        [[ ! -f "$bin" ]] && status="${RED}✘ missing${NC}"
        echo -e "  ${status}  ${BOLD}${name}${NC}${size}"
        (( count++ )) || true
    done < "$REGISTRY"

    echo ""
    echo -e "  ${BOLD}${count}${NC} app(s) managed by appimage."
    echo ""
}

# ── Command: info ─────────────────────────────────────────────────
cmd_info() {
    local APP_NAME="${1:-}"
    [[ -z "$APP_NAME" ]] && die "Usage: appimage --info <Name>"

    local APP_ID; APP_ID="$(registry_id "$APP_NAME")"
    [[ -z "$APP_ID" ]] && APP_ID="$(to_id "$APP_NAME")"

    local APP_BIN="$APPS_DIR/${APP_NAME}/${APP_NAME}.AppImage"
    local ICON_PATH="${ICON_DIR}/${APP_ID}.png"
    local DESKTOP_FILE="${DESKTOP_DIR}/${APP_ID}.desktop"

    header "Info: ${APP_NAME}"
    echo -e "  ID          : $APP_ID"
    echo -e "  AppImage    : $APP_BIN $( [[ -f "$APP_BIN" ]] && echo "${GREEN}[found]${NC}" || echo "${RED}[missing]${NC}" )"
    echo -e "  Icon        : $ICON_PATH $( [[ -f "$ICON_PATH" ]] && echo "${GREEN}[found]${NC}" || echo "${RED}[missing]${NC}" )"
    echo -e "  Desktop     : $DESKTOP_FILE $( [[ -f "$DESKTOP_FILE" ]] && echo "${GREEN}[found]${NC}" || echo "${RED}[missing]${NC}" )"

    if [[ -f "$APP_BIN" ]]; then
        local size mtime
        size="$(du -sh "$APP_BIN" 2>/dev/null | cut -f1)"
        mtime="$(stat -c '%y' "$APP_BIN" 2>/dev/null | cut -d. -f1)"
        echo -e "  Size        : $size"
        echo -e "  Modified    : $mtime"
    fi

    if [[ -f "$DESKTOP_FILE" ]]; then
        echo ""
        echo -e "  ${BOLD}.desktop contents:${NC}"
        sed 's/^/    /' "$DESKTOP_FILE"
    fi
    echo ""
}

# ── Router ────────────────────────────────────────────────────────
CMD="${1:-}"
shift || true

case "$CMD" in
    --install)        cmd_install        "$@" ;;
    --uninstall)      cmd_uninstall      "$@" ;;
    --update)         cmd_update         "$@" ;;
    --run)            cmd_run            "$@" ;;
    --list)           cmd_list                ;;
    --info)           cmd_info           "$@" ;;
    --self-install)   cmd_self_install        ;;
    --self-uninstall) cmd_self_uninstall      ;;
    --help|-h|"")     cmd_help                ;;
    *)                die "Unknown command: $CMD  (run 'appimage --help')" ;;
esac
