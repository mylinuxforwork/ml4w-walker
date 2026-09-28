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

1. Clones ml4w-walker into `$HOME/.local/share/ml4w-walker` and links the
   `ml4w-walker` command into `$HOME/.local/bin`.
2. Installs the libraries Walker needs (GTK4, gtk4-layer-shell, poppler-glib) and
   the tools your providers need with your package manager. This step uses `sudo`.
3. Downloads the latest Walker and Elephant release binaries from GitHub. AUR
   or distribution packages of Walker and Elephant are not used.
4. Installs `walker` and `elephant` into `$HOME/.local/bin` and the providers
   into `$HOME/.config/elephant/providers`.

Requires `git`, `curl` and `tar`.

After the installation, use the [`ml4w-walker` command](#the-ml4w-walker-command)
to start, update and add or remove providers. Running the install script again
works as well: the provider list you pass replaces the previous one, and
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

## The ml4w-walker command

```bash
ml4w-walker [command]
```

| Command | Description |
|---|---|
| `start` | Start Elephant and then Walker. Default when no command is given. Skips what is already running |
| `stop` | Stop Walker and Elephant |
| `restart` | Stop and start Walker and Elephant |
| `status` | Show the installed versions, providers and running processes |
| `providers` | List all providers and mark the installed ones |
| `add <provider>...` | Install providers and the packages they need. Add `--no-deps` to skip the packages |
| `remove <provider>...` | Remove providers |
| `update` | Update ml4w-walker, Walker, Elephant and all providers. Options are passed to `install.sh`, e.g. `--force` |
| `uninstall` | Remove Walker, Elephant and ml4w-walker |
| `help` | Show the help |

Providers can be separated by spaces or commas, e.g. `ml4w-walker add calc clipboard`.

`add`, `remove` and `update` restart Walker and Elephant if they were running.
`add` and `remove` keep the installed Walker and Elephant versions; only
`update` installs new versions.

Elephant and Walker write their output to `~/.local/state/ml4w-walker/elephant.log`
and `walker.log`.

## Start

The ML4W Dotfiles start Walker and Elephant from `ml4w-autostart`. To start them
yourself, add this line to your autostart:

```bash
~/.local/bin/ml4w-walker
```

It starts Elephant, waits until it is ready and then starts Walker in the
background. Open the launcher with:

```bash
walker
```

## Configuration

- Elephant: `~/.config/elephant/`. Run `elephant generatedoc` for the documentation
  of all settings, or `elephant generatedoc <provider>` for one provider.
- Walker: `~/.config/walker/config.toml`. See the
  [Walker documentation](https://benz.gitbook.io/walker/).

The script does not change your configuration.

## Troubleshooting

**A provider does not show up.** Run `elephant listproviders` while Elephant is
running. If the provider is missing, check `~/.local/state/ml4w-walker/elephant.log`
or run `ml4w-walker stop` and start `elephant --debug` in a terminal.

**Walker or Elephant from a package is still installed.** Elephant also loads
providers from `/usr/lib/elephant`, and those do not work with the Elephant from
this script. The script warns if it finds them. Remove the packages, e.g. on
Arch:

```bash
sudo pacman -Rns $(pacman -Qqs '^(elephant|walker)')
```

## Uninstall

```bash
ml4w-walker uninstall
```

This stops Walker and Elephant, and removes both binaries, the providers
installed by the script, the `ml4w-walker` command, `~/.local/share/ml4w-walker`
and `~/.local/state/ml4w-walker`. Your configuration in `~/.config/elephant` and
`~/.config/walker` and the distribution packages are kept. Remove `ml4w-walker`
from your autostart yourself.
