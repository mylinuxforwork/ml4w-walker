# ML4W Walker

An install script for the application launcher [Walker](https://github.com/abenz1267/walker)
and its backend [Elephant](https://github.com/abenz1267/elephant), including the
Elephant providers you choose. Part of
[ML4W OS](https://github.com/mylinuxforwork/dotfiles), but it also works on its own.

Supported distributions (x86_64 only):

- Arch Linux
- Fedora
- openSUSE Tumbleweed
- Ubuntu 25.10 and newer (26.04 LTS)

## Installation

```bash
curl -sSL https://raw.githubusercontent.com/mylinuxforwork/ml4w-walker/main/install.sh | bash
```

This installs Walker, Elephant and the providers `desktopapplications` and
`menus`. To choose other providers, pass them as a comma-separated list:

```bash
curl -sSL https://raw.githubusercontent.com/mylinuxforwork/ml4w-walker/main/install.sh | bash -s -- --providers desktopapplications,menus,calc,clipboard
```

The script:

1. Installs the libraries Walker needs (GTK4, gtk4-layer-shell, poppler-glib) and
   the tools your providers need with your package manager. This step uses `sudo`.
2. Downloads the latest Walker and Elephant release binaries from GitHub. AUR
   or distribution packages of Walker and Elephant are not used.
3. Installs `walker` and `elephant` into `$HOME/.local/bin` and the providers
   into `$HOME/.config/elephant/providers`.

Run it again to update. Nothing is downloaded if the installed versions are
already the latest. The provider list you pass always replaces the previous one:
providers that are missing from the list are removed.

`$HOME/.local/bin` must be in your `$PATH`. Most distributions add it by default.
If yours does not, add this line to your shell configuration (e.g. `~/.bashrc`
or `~/.zshrc`):

```bash
export PATH="$HOME/.local/bin:$PATH"
```

### Options

| Option | Description |
|---|---|
| `--providers a,b,c` | Elephant providers to install. Default: `desktopapplications,menus` |
| `--elephant-version TAG` | Install a specific Elephant release, e.g. `v2.22.1`. Default: latest |
| `--walker-version TAG` | Install a specific Walker release, e.g. `v2.17.1`. Default: latest |
| `--no-deps` | Do not install distribution packages (no `sudo` needed) |
| `--force` | Download and reinstall even if up to date |
| `--list-providers` | List all available providers |
| `-h`, `--help` | Show the help |

Instead of `--providers` you can also set `ML4W_WALKER_PROVIDERS`.

## Providers

| Provider | Description | Installed dependencies / requirements |
|---|---|---|
| `desktopapplications` | Launch installed applications | |
| `menus` | Custom menus | |
| `providerlist` | Switch between providers | |
| `calc` | Calculator and unit conversion | qalc |
| `clipboard` | Clipboard history | wl-clipboard, ImageMagick |
| `files` | Find and open files | fd, wl-clipboard |
| `runner` | Run commands from `$PATH` | |
| `websearch` | Search the web | |
| `symbols` | Emojis and symbols | |
| `unicode` | Unicode characters | |
| `snippets` | Text snippets | |
| `bookmarks` | Bookmarks | |
| `todo` | Todo list with notifications | libnotify |
| `bluetooth` | Bluetooth devices | bluez |
| `playerctl` | Media player control | playerctl |
| `wireplumber` | Audio input and output | |
| `windows` | Find and focus windows | niri |
| `niriactions` | niri actions | niri |
| `nirisessions` | niri app sessions | niri |
| `archlinuxpkgs` | Arch packages | Arch Linux only |
| `dnfpackages` | dnf packages | Fedora only |
| `aptpackages` | apt packages | Ubuntu only |
| `1password` | 1Password vaults | 1Password CLI (`op`), not installed by the script |
| `bitwarden` | Bitwarden vaults | `rbw`, not installed by the script |
| `protonpass` | Proton Pass vaults | Proton Pass CLI (`pass-cli`), not installed by the script |

Elephant disables a provider when the tool it needs is missing.

## Start

Elephant must run before Walker. The ML4W Dotfiles start both from
`ml4w-autostart`. To start them yourself, add these lines to your autostart,
Elephant first:

```bash
~/.local/bin/elephant &
~/.local/bin/walker --gapplication-service &
```

Walker then runs in the background and opens with:

```bash
walker
```

After an update, restart both so the new version is used:

```bash
pkill -x walker; pkill -x elephant
~/.local/bin/elephant &
~/.local/bin/walker --gapplication-service &
```

## Configuration

- Elephant: `~/.config/elephant/`. Run `elephant generatedoc` for the documentation
  of all settings, or `elephant generatedoc <provider>` for one provider.
- Walker: `~/.config/walker/config.toml`. See the
  [Walker documentation](https://benz.gitbook.io/walker/).

The script does not change your configuration.

## Troubleshooting

**A provider does not show up.** Run `elephant listproviders` while Elephant is
running. If the provider is missing, start `elephant --debug` in a terminal and
look for errors.

**Walker or Elephant from a package is still installed.** Elephant also loads
providers from `/usr/lib/elephant`, and those do not work with the Elephant from
this script. The script warns if it finds them. Remove the packages, e.g. on
Arch:

```bash
sudo pacman -Rns $(pacman -Qqs '^(elephant|walker)')
```

## Uninstall

```bash
curl -sSL https://raw.githubusercontent.com/mylinuxforwork/ml4w-walker/main/uninstall.sh | bash
```

This stops Walker and Elephant, removes both binaries, the providers installed by
the script and `~/.local/share/ml4w-walker`. Your configuration in
`~/.config/elephant` and `~/.config/walker` and the distribution packages are
kept. Remove the lines from your autostart yourself.
