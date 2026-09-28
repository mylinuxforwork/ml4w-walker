#!/usr/bin/env bash
#
# Uninstall walker and elephant installed by ml4w-walker
#

set -euo pipefail

BIN_DIR="$HOME/.local/bin"
PROVIDER_DIR="$HOME/.config/elephant/providers"
STATE_DIR="$HOME/.local/share/ml4w-walker"
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

    if [ ! -f "$MANIFEST" ]; then
        echo ":: Nothing to do: $MANIFEST does not exist."
        exit 0
    fi

    providers="$(grep -E '^providers=' "$MANIFEST" | head -n1 | cut -d= -f2- || true)"

    stop_binary walker
    stop_binary elephant

    for bin in walker elephant; do
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

    echo ":: Removing $STATE_DIR"
    rm -rf "$STATE_DIR"
    echo ":: Done."

    echo ":: Your configuration in ~/.config/elephant and ~/.config/walker was kept. Remove it manually if you no longer need it."
    echo ":: Distribution packages installed as dependencies were kept."
    echo ":: Remove the elephant and walker lines from your autostart."
}

main "$@"
