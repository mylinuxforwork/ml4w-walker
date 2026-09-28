#!/usr/bin/env bash
#
# Uninstall walker and elephant installed by ml4w-walker
#

set -euo pipefail

BIN_DIR="$HOME/.local/bin"
PROVIDER_DIR="$HOME/.config/elephant/providers"
INSTALL_DIR="$HOME/.local/share/ml4w-walker"
STATE_DIR="$HOME/.local/state/ml4w-walker"
MANIFEST="$STATE_DIR/manifest"

# Stop processes that run the binary from $BIN_DIR, not other installations
stop_binary() {
    local name="$1" pid
    for pid in $(pgrep -x "$name" 2>/dev/null || true); do
        if [ "$(readlink "/proc/$pid/exe" 2>/dev/null || true)" = "$BIN_DIR/$name" ]; then
            echo ":: Stopping $name ($pid)"
            kill "$pid" 2>/dev/null || true
        fi
    done
}

main() {
    local providers p

    # Earlier versions kept the manifest in $INSTALL_DIR
    if [ ! -f "$MANIFEST" ] && [ -f "$INSTALL_DIR/manifest" ]; then
        MANIFEST="$INSTALL_DIR/manifest"
    fi

    if [ ! -f "$MANIFEST" ] && [ ! -d "$INSTALL_DIR" ] && [ ! -L "$BIN_DIR/ml4w-walker" ]; then
        echo ":: Nothing to do: ml4w-walker is not installed."
        exit 0
    fi

    providers=""
    if [ -f "$MANIFEST" ]; then
        providers="$(grep -E '^providers=' "$MANIFEST" | head -n1 | cut -d= -f2- || true)"
    fi

    stop_binary walker
    stop_binary elephant

    # Without a manifest the binaries may belong to another installation
    for bin in walker elephant; do
        [ -f "$MANIFEST" ] || continue
        if [ -f "$BIN_DIR/$bin" ]; then
            echo ":: Removing $BIN_DIR/$bin"
            rm -f "$BIN_DIR/$bin"
        fi
    done

    IFS=',' read -ra list <<<"$providers"
    for p in "${list[@]}"; do
        if [ -f "$PROVIDER_DIR/$p.so" ]; then
            echo ":: Removing provider $p"
            rm -f "$PROVIDER_DIR/$p.so"
        fi
    done
    rmdir "$PROVIDER_DIR" 2>/dev/null || true

    if [ -L "$BIN_DIR/ml4w-walker" ]; then
        echo ":: Removing $BIN_DIR/ml4w-walker"
        rm -f "$BIN_DIR/ml4w-walker"
    fi

    for dir in "$INSTALL_DIR" "$STATE_DIR"; do
        if [ -d "$dir" ]; then
            echo ":: Removing $dir"
            rm -rf "$dir"
        fi
    done
    echo ":: Done."

    echo ":: Your configuration in ~/.config/elephant and ~/.config/walker was kept. Remove it manually if you no longer need it."
    echo ":: Distribution packages installed as dependencies were kept."
    echo ":: Remove ml4w-walker from your autostart."
}

main "$@"
