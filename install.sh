#!/usr/bin/env bash
#
# HyprMap install script.
#
#   ./install.sh              Install the standalone build (plain Hyprland +
#                             Quickshell, e.g. Fedora).
#   ./install.sh --omarchy    Install as an Omarchy shell plugin (Arch +
#                             Omarchy).
#
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CFG="${XDG_CONFIG_HOME:-$HOME/.config}"

MODE="${1:-standalone}"

case "$MODE" in
  --omarchy|omarchy|-o)
    PLUGIN_DIR="$CFG/omarchy/plugins/hyprmap"

    echo "[HyprMap] Installing Omarchy plugin -> $PLUGIN_DIR"
    mkdir -p "$PLUGIN_DIR"
    cp "$REPO_DIR/omarchy/hyprmap/manifest.json" "$PLUGIN_DIR/"
    cp "$REPO_DIR/omarchy/hyprmap/Minimap.qml" "$PLUGIN_DIR/"
    cp "$REPO_DIR/omarchy/hyprmap/Model.js" "$PLUGIN_DIR/"

    # --- Register the plugin in shell.json (with a backup) ---
    SHELL_JSON="$CFG/omarchy/shell.json"
    if [ -f "$SHELL_JSON" ]; then
      if ! python3 - "$SHELL_JSON" <<'PY'
import json, sys
path = sys.argv[1]
data = json.load(open(path))
plugins = data.setdefault("plugins", [])
for p in plugins:
    if isinstance(p, dict) and p.get("id") == "hyprmap":
        sys.exit(0)
plugins.append({"id": "hyprmap"})
tmp = path + ".hyprmap.tmp"
with open(tmp, "w") as fh:
    json.dump(data, fh, indent=2, ensure_ascii=False)
    fh.write("\n")
# Only replace if valid
json.load(open(tmp))
import shutil
shutil.copy(path, path + ".hyprmap.bak")
shutil.move(tmp, path)
print("[HyprMap] plugin id added to shell.json (backup saved)")
PY
      then
        echo "[HyprMap] shell.json updated"
      fi
    else
      echo "[HyprMap] warning: $SHELL_JSON not found; register the plugin manually."
    fi

    # --- Add the SUPER+M binding to bindings.lua (with a backup) ---
    BINDINGS="$CFG/hypr/bindings.lua"
    if [ -f "$BINDINGS" ]; then
      if ! grep -q "toggle hyprmap" "$BINDINGS"; then
        cp "$BINDINGS" "$BINDINGS.hyprmap.bak"
        printf '\no.bind("SUPER + M", "HyprMap", "omarchy-shell shell toggle hyprmap")\n' >> "$BINDINGS"
        echo "[HyprMap] binding added to bindings.lua (backup saved)"
      else
        echo "[HyprMap] binding already present in bindings.lua"
      fi
    else
      echo "[HyprMap] warning: $BINDINGS not found; add the binding manually:"
      echo '  o.bind("SUPER + M", "HyprMap", "omarchy-shell shell toggle hyprmap")'
    fi

    echo
    echo "[HyprMap] Reload your config:"
    echo "  hyprctl reload"
    echo "  omarchy-shell shell rescanPlugins"
    ;;

  *)
    QUICKSHIELD_DIR="$CFG/quickshell/hyprmap"
    BIN_DIR="${XDG_BIN_HOME:-$HOME/.local/bin}"

    echo "[HyprMap] Installing standalone build -> $QUICKSHIELD_DIR/"

    if ! command -v quickshell >/dev/null 2>&1; then
      echo "[HyprMap] ERROR: 'quickshell' not found in PATH."
      echo "  Fedora: sudo dnf copr enable errornointernet/quickshell && sudo dnf install quickshell"
      echo "  Arch:   sudo pacman -S quickshell   (or AUR: yay -S quickshell-git)"
      exit 1
    fi
    if ! command -v hyprctl >/dev/null 2>&1; then
      echo "[HyprMap] ERROR: 'hyprctl' not found; HyprMap requires Hyprland."
      exit 1
    fi

    mkdir -p "$QUICKSHIELD_DIR"
    cp "$REPO_DIR/standalone/hyprmap.qml" "$QUICKSHIELD_DIR/shell.qml"
    cp "$REPO_DIR/standalone/Model.js" "$QUICKSHIELD_DIR/Model.js"

    mkdir -p "$BIN_DIR"
    cp "$REPO_DIR/standalone/hyprmap-toggle" "$BIN_DIR/hyprmap-toggle"
    chmod +x "$BIN_DIR/hyprmap-toggle"

    echo
    echo "[HyprMap] Installed. Next steps:"
    echo "  1. Autostart + keybinding — add to ~/.config/hypr/hyprland.conf:"
    echo "       exec-once = quickshell -c hyprmap"
    echo "       bind = SUPER, M, exec, quickshell ipc -c hyprmap call hyprmap toggle"
    echo "     (or use the preset: $(realpath "$REPO_DIR/standalone/hyprmap.hyprland.conf"))"
    echo "  2. Reload Hyprland:  hyprctl reload"
    echo "  3. Toggle anytime with:  $BIN_DIR/hyprmap-toggle"
    ;;
esac

echo
echo "[HyprMap] Done."