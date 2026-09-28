#!/usr/bin/env bash
#
# Install or update walker and elephant with selected providers
#
# Usage:
#   curl -sSL https://raw.githubusercontent.com/mylinuxforwork/ml4w-walker/main/install.sh | bash
#   curl -sSL .../install.sh | bash -s -- --providers desktopapplications,menus,calc
#

set -euo pipefail

ELEPHANT_REPO="abenz1267/elephant"
WALKER_REPO="abenz1267/walker"
BIN_DIR="$HOME/.local/bin"
PROVIDER_DIR="$HOME/.config/elephant/providers"
STATE_DIR="$HOME/.local/share/ml4w-walker"
MANIFEST="$STATE_DIR/manifest"

DEFAULT_PROVIDERS="desktopapplications,menus"
MIN_GLIBC="2.39"
MIN_UBUNTU="25.10"

ALL_PROVIDERS=(
    1password aptpackages archlinuxpkgs bitwarden bluetooth bookmarks calc
    clipboard desktopapplications dnfpackages files menus niriactions
    nirisessions playerctl protonpass providerlist runner snippets symbols
    todo unicode websearch windows wireplumber
)

PROVIDERS="${ML4W_WALKER_PROVIDERS:-$DEFAULT_PROVIDERS}"
ELEPHANT_VERSION="latest"
WALKER_VERSION="latest"
INSTALL_DEPS=1
FORCE=0
DISTRO=""
TMP_DIR=""

usage() {
    cat <<EOF
Install or update walker and elephant with selected providers.

Usage: install.sh [options]

Options:
  --providers a,b,c        Elephant providers to install
                           (default: $DEFAULT_PROVIDERS)
  --elephant-version TAG   Install a specific elephant release (default: latest)
  --walker-version TAG     Install a specific walker release (default: latest)
  --no-deps                Do not install distribution packages
  --force                  Download and reinstall even if up to date
  --list-providers         List available providers and exit
  -h, --help               Show this help

The provider list can also be set with ML4W_WALKER_PROVIDERS.
Providers installed by a previous run that are not in the list are removed.
EOF
}

info() { echo ":: $*"; }
warn() { echo ":: WARNING: $*"; }
die() {
    echo ":: ERROR: $*"
    exit 1
}

cleanup() {
    if [ -n "$TMP_DIR" ]; then
        rm -rf "$TMP_DIR"
    fi
}

parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --providers)
                [ $# -ge 2 ] || die "--providers needs a value"
                PROVIDERS="$2"
                shift 2
                ;;
            --providers=*)
                PROVIDERS="${1#*=}"
                shift
                ;;
            --elephant-version)
                [ $# -ge 2 ] || die "--elephant-version needs a value"
                ELEPHANT_VERSION="$2"
                shift 2
                ;;
            --walker-version)
                [ $# -ge 2 ] || die "--walker-version needs a value"
                WALKER_VERSION="$2"
                shift 2
                ;;
            --no-deps)
                INSTALL_DEPS=0
                shift
                ;;
            --force)
                FORCE=1
                shift
                ;;
            --list-providers)
                printf '%s\n' "${ALL_PROVIDERS[@]}"
                exit 0
                ;;
            -h | --help)
                usage
                exit 0
                ;;
            *)
                usage
                die "Unknown option: $1"
                ;;
        esac
    done
}

# Normalize the comma separated provider list: trim, dedupe, validate
normalize_providers() {
    local p valid list=()
    IFS=',' read -ra items <<<"$PROVIDERS"
    for p in "${items[@]}"; do
        p="${p//[[:space:]]/}"
        [ -n "$p" ] || continue
        valid=0
        for v in "${ALL_PROVIDERS[@]}"; do
            [ "$p" = "$v" ] && valid=1 && break
        done
        [ "$valid" = 1 ] || die "Unknown provider: $p (see --list-providers)"
        case " ${list[*]} " in
            *" $p "*) ;;
            *) list+=("$p") ;;
        esac
    done
    [ ${#list[@]} -gt 0 ] || die "No providers selected"
    PROVIDERS="$(IFS=','; echo "${list[*]}")"
}

version_ge() {
    [ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -n1)" = "$2" ]
}

detect_distro() {
    local id="" like="" version=""
    if [ -r /etc/os-release ]; then
        # shellcheck disable=SC1091
        id="$(. /etc/os-release && echo "${ID:-}")"
        like="$(. /etc/os-release && echo "${ID_LIKE:-}")"
        version="$(. /etc/os-release && echo "${VERSION_ID:-}")"
    fi

    case " $id $like " in
        *" arch "*) DISTRO="arch" ;;
        *" fedora "*) DISTRO="fedora" ;;
        *" opensuse-tumbleweed "*) DISTRO="opensuse" ;;
        *" ubuntu "*)
            DISTRO="ubuntu"
            if [ "$id" = "ubuntu" ] && [ -n "$version" ] && ! version_ge "$version" "$MIN_UBUNTU"; then
                die "Ubuntu $version is not supported. Walker needs gtk4-layer-shell, which is available from Ubuntu $MIN_UBUNTU."
            fi
            ;;
        *) DISTRO="" ;;
    esac
}

preflight() {
    local arch glibc

    arch="$(uname -m)"
    [ "$arch" = "x86_64" ] || die "Only x86_64 is supported (walker and elephant publish no $arch builds)."

    for cmd in curl tar; do
        command -v "$cmd" >/dev/null 2>&1 || die "$cmd is required but not installed."
    done

    glibc="$(ldd --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+$' || true)"
    if [ -z "$glibc" ]; then
        warn "Could not detect the glibc version. Walker needs glibc $MIN_GLIBC or newer."
    elif ! version_ge "$glibc" "$MIN_GLIBC"; then
        die "glibc $glibc is too old. Walker needs glibc $MIN_GLIBC or newer."
    fi

    for dir in /usr/lib/elephant /usr/lib64/elephant /usr/local/lib/elephant /usr/local/lib64/elephant; do
        if [ -d "$dir" ] && compgen -G "$dir/*.so" >/dev/null; then
            warn "Found elephant providers in $dir (installed by a package)."
            warn "Elephant loads them before the ones in $PROVIDER_DIR and they will not work with this elephant build."
            warn "Remove the elephant packages of your distribution, e.g. on Arch: pacman -Rns \$(pacman -Qqs '^elephant')"
        fi
    done
}

# Distribution packages needed by walker itself
base_packages() {
    case "$DISTRO" in
        arch) echo "gtk4 gtk4-layer-shell poppler-glib" ;;
        fedora) echo "gtk4 gtk4-layer-shell poppler-glib" ;;
        opensuse) echo "libgtk-4-1 libgtk4-layer-shell0 libpoppler-glib8" ;;
        ubuntu) echo "libgtk-4-1 libgtk4-layer-shell0 libpoppler-glib8t64" ;;
    esac
}

# Distribution packages needed by a provider
provider_packages() {
    case "$DISTRO:$1" in
        arch:calc) echo "libqalculate" ;;
        fedora:calc) echo "libqalculate" ;;
        opensuse:calc) echo "qalculate" ;;
        ubuntu:calc) echo "qalc" ;;

        arch:clipboard) echo "wl-clipboard imagemagick" ;;
        fedora:clipboard | opensuse:clipboard) echo "wl-clipboard ImageMagick" ;;
        ubuntu:clipboard) echo "wl-clipboard imagemagick" ;;

        arch:files | opensuse:files) echo "fd wl-clipboard" ;;
        fedora:files | ubuntu:files) echo "fd-find wl-clipboard" ;;

        arch:bluetooth) echo "bluez bluez-utils" ;;
        *:bluetooth) echo "bluez" ;;

        *:playerctl) echo "playerctl" ;;

        arch:todo | fedora:todo) echo "libnotify" ;;
        opensuse:todo) echo "libnotify-tools" ;;
        ubuntu:todo) echo "libnotify-bin" ;;

        arch:1password | arch:bitwarden | arch:protonpass) echo "wl-clipboard libnotify" ;;
        fedora:1password | fedora:bitwarden | fedora:protonpass) echo "wl-clipboard libnotify" ;;
        opensuse:1password | opensuse:bitwarden | opensuse:protonpass) echo "wl-clipboard libnotify-tools" ;;
        ubuntu:1password | ubuntu:bitwarden | ubuntu:protonpass) echo "wl-clipboard libnotify-bin" ;;
    esac
}

# Hints for providers that need tools this script does not install
provider_notes() {
    local p
    IFS=',' read -ra list <<<"$PROVIDERS"
    for p in "${list[@]}"; do
        case "$p" in
            1password) info "Note: 1password needs the 1Password CLI (op)." ;;
            bitwarden) info "Note: bitwarden needs rbw." ;;
            protonpass) info "Note: protonpass needs the Proton Pass CLI (pass-cli)." ;;
            niriactions | nirisessions | windows) info "Note: $p needs the niri compositor." ;;
            archlinuxpkgs) [ "$DISTRO" = "arch" ] || warn "archlinuxpkgs only works on Arch Linux." ;;
            dnfpackages) [ "$DISTRO" = "fedora" ] || warn "dnfpackages only works with dnf (Fedora)." ;;
            aptpackages) [ "$DISTRO" = "ubuntu" ] || warn "aptpackages only works with apt (Ubuntu/Debian)." ;;
        esac
    done
}

install_dependencies() {
    local pkgs p sudo=""

    if [ "$INSTALL_DEPS" = 0 ]; then
        info "Skipping distribution packages (--no-deps)"
        return
    fi
    if [ -z "$DISTRO" ]; then
        die "Unsupported distribution. Install the dependencies manually and run again with --no-deps."
    fi

    pkgs="$(base_packages)"
    IFS=',' read -ra list <<<"$PROVIDERS"
    for p in "${list[@]}"; do
        pkgs="$pkgs $(provider_packages "$p")"
    done
    # shellcheck disable=SC2086
    pkgs="$(printf '%s\n' $pkgs | sort -u | tr '\n' ' ')"

    if [ "$(id -u)" -ne 0 ]; then
        command -v sudo >/dev/null 2>&1 || die "sudo is required to install packages. Or run again with --no-deps."
        sudo="sudo"
    fi

    info "Installing packages: $pkgs"
    # shellcheck disable=SC2086
    case "$DISTRO" in
        arch) $sudo pacman -S --needed --noconfirm $pkgs ;;
        fedora) $sudo dnf install -y $pkgs ;;
        opensuse) $sudo zypper --non-interactive install $pkgs ;;
        ubuntu)
            $sudo apt-get update
            $sudo apt-get install -y $pkgs
            ;;
    esac
}

# Resolve "latest" to a tag by following the GitHub redirect (no API rate limit)
resolve_tag() {
    local repo="$1" version="$2" url
    if [ "$version" != "latest" ]; then
        echo "$version"
        return
    fi
    url="$(curl -fsSL -o /dev/null -w '%{url_effective}' "https://github.com/$repo/releases/latest")" ||
        die "Could not look up the latest release of $repo"
    case "$url" in
        */releases/tag/*) echo "${url##*/}" ;;
        *) die "Could not look up the latest release of $repo" ;;
    esac
}

manifest_get() {
    [ -f "$MANIFEST" ] || return 0
    grep -E "^$1=" "$MANIFEST" | head -n1 | cut -d= -f2- || true
}

# Download a release tarball and extract the file $3 into the staging dir as $4
fetch() {
    local repo="$1" tag="$2" asset="$3" member="$4" target="$5"
    local url="https://github.com/$repo/releases/download/$tag/$asset"
    info "Downloading $asset ($tag)"
    curl -fsSL --retry 3 -o "$TMP_DIR/$asset" "$url" || die "Download failed: $url"
    tar -xzf "$TMP_DIR/$asset" -C "$TMP_DIR" "$member" || die "$asset does not contain $member"
    if [ "$member" != "$target" ]; then
        mv "$TMP_DIR/$member" "$TMP_DIR/$target"
    fi
    rm -f "$TMP_DIR/$asset"
}

# Copy next to the target and rename, so running binaries are not touched
place() {
    local src="$1" dest="$2" mode="$3"
    install -m "$mode" "$src" "$dest.ml4w-new"
    mv -f "$dest.ml4w-new" "$dest"
}

main() {
    parse_args "$@"
    normalize_providers
    detect_distro
    preflight

    local elephant_tag walker_tag old_elephant old_walker old_providers
    local update_elephant=0 update_walker=0 p
    local -a providers new_providers=() removed_providers=()

    info "Providers: $PROVIDERS"

    elephant_tag="$(resolve_tag "$ELEPHANT_REPO" "$ELEPHANT_VERSION")"
    walker_tag="$(resolve_tag "$WALKER_REPO" "$WALKER_VERSION")"
    old_elephant="$(manifest_get elephant)"
    old_walker="$(manifest_get walker)"
    old_providers="$(manifest_get providers)"

    if [ "$FORCE" = 1 ] || [ "$elephant_tag" != "$old_elephant" ] || [ ! -x "$BIN_DIR/elephant" ]; then
        update_elephant=1
    fi
    if [ "$FORCE" = 1 ] || [ "$walker_tag" != "$old_walker" ] || [ ! -x "$BIN_DIR/walker" ]; then
        update_walker=1
    fi

    IFS=',' read -ra providers <<<"$PROVIDERS"
    for p in "${providers[@]}"; do
        # Providers must match the elephant build, so all are replaced when elephant changes
        if [ "$update_elephant" = 1 ] || [ ! -f "$PROVIDER_DIR/$p.so" ]; then
            new_providers+=("$p")
        fi
    done
    if [ -n "$old_providers" ]; then
        IFS=',' read -ra old_list <<<"$old_providers"
        for p in "${old_list[@]}"; do
            case ",$PROVIDERS," in
                *",$p,"*) ;;
                *) removed_providers+=("$p") ;;
            esac
        done
    fi

    install_dependencies

    if [ "$update_elephant" = 0 ] && [ "$update_walker" = 0 ] &&
        [ ${#new_providers[@]} -eq 0 ] && [ ${#removed_providers[@]} -eq 0 ]; then
        info "elephant $elephant_tag and walker $walker_tag are up to date."
    else
        TMP_DIR="$(mktemp -d)"
        trap cleanup EXIT

        # Download everything first, so a failed download leaves the old install intact
        if [ "$update_elephant" = 1 ]; then
            fetch "$ELEPHANT_REPO" "$elephant_tag" "elephant-linux-amd64.tar.gz" \
                "elephant-linux-amd64" "elephant"
        fi
        for p in "${new_providers[@]}"; do
            fetch "$ELEPHANT_REPO" "$elephant_tag" "$p-linux-amd64.tar.gz" \
                "$p-linux-amd64.so" "$p.so"
        done
        if [ "$update_walker" = 1 ]; then
            fetch "$WALKER_REPO" "$walker_tag" "walker-$walker_tag-x86_64-unknown-linux-gnu.tar.gz" \
                "walker" "walker"
        fi

        mkdir -p "$BIN_DIR" "$PROVIDER_DIR" "$STATE_DIR"

        if [ "$update_elephant" = 1 ]; then
            info "Installing elephant $elephant_tag into $BIN_DIR"
            place "$TMP_DIR/elephant" "$BIN_DIR/elephant" 755
        fi
        for p in "${new_providers[@]}"; do
            info "Installing provider $p into $PROVIDER_DIR"
            place "$TMP_DIR/$p.so" "$PROVIDER_DIR/$p.so" 644
        done
        for p in "${removed_providers[@]}"; do
            if [ -f "$PROVIDER_DIR/$p.so" ]; then
                info "Removing provider $p"
                rm -f "$PROVIDER_DIR/$p.so"
            fi
        done
        if [ "$update_walker" = 1 ]; then
            info "Installing walker $walker_tag into $BIN_DIR"
            place "$TMP_DIR/walker" "$BIN_DIR/walker" 755
        fi

        cat >"$MANIFEST" <<EOF
elephant=$elephant_tag
walker=$walker_tag
providers=$PROVIDERS
EOF
        info "walker and elephant installed successfully."

        if pgrep -x elephant >/dev/null 2>&1 || pgrep -x walker >/dev/null 2>&1; then
            info "elephant or walker is running. Restart both to use the new version:"
            info "  pkill -x walker; pkill -x elephant"
            info "  elephant & walker --gapplication-service &"
        fi
    fi

    provider_notes

    case ":$PATH:" in
        *":$BIN_DIR:"*) ;;
        *)
            warn "$BIN_DIR is not in your \$PATH."
            warn "Add it to your shell configuration, e.g. in ~/.bashrc or ~/.zshrc:"
            warn "export PATH=\"\$HOME/.local/bin:\$PATH\""
            ;;
    esac
    for cmd in elephant walker; do
        local found
        found="$(command -v "$cmd" 2>/dev/null || true)"
        if [ -n "$found" ] && [ "$found" != "$BIN_DIR/$cmd" ]; then
            warn "$cmd resolves to $found, not $BIN_DIR/$cmd. Remove the other installation."
        fi
    done

    info "Start both from your autostart (elephant must run before walker):"
    info "  $BIN_DIR/elephant &"
    info "  $BIN_DIR/walker --gapplication-service &"
    info "Open the launcher with: walker"
}

main "$@"
