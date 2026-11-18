# Antigravity for Linux

One-command installer/updater for **Google Antigravity 2.0** and **Antigravity IDE** on Linux, using Google's official tarballs.

> Community helper. Not affiliated with, endorsed by, or supported by Google. It does not mirror or modify Antigravity: the latest official tarball is resolved from <https://antigravity.google/download> at install time.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/ongtungduong/antigravity-for-linux/main/install.sh | bash
```

The script asks for `sudo` itself and installs the Antigravity 2.0 desktop app. Pass flags after `bash -s --`:

```bash
# Desktop app + IDE
curl -fsSL https://raw.githubusercontent.com/ongtungduong/antigravity-for-linux/main/install.sh | bash -s -- --all

# IDE only
curl -fsSL https://raw.githubusercontent.com/ongtungduong/antigravity-for-linux/main/install.sh | bash -s -- --ide

# Behind a proxy
curl -fsSL https://raw.githubusercontent.com/ongtungduong/antigravity-for-linux/main/install.sh | bash -s -- --all --proxy http://HOST:PORT
```

Prefer to read it first? Download `install.sh`, review it, then run `bash install.sh --all`.

When piped, the script re-runs itself under `sudo` from the same stream, so what runs as root is exactly what you piped (pin a tag or commit in the URL to install a reviewed version). `--proxy http://user:pass@host` credentials are visible in the process list while it runs.

## Manage

```bash
antigravity-linux update --all   # update (or: update-antigravity, update-antigravity-ide)
antigravity-linux --status       # show installed apps and versions (works offline)
antigravity-linux --uninstall    # remove helper-managed files (works offline; user settings are kept)
```

## Options

```text
--desktop          Install/update Antigravity 2.0 desktop app only (default)
--ide              Install/update Antigravity IDE only
--all              Install/update desktop app + IDE
--cli              Also run Google's official Antigravity CLI installer
--no-nautilus      Skip GNOME Files/Nautilus context-menu helper
--no-apt           Do not install apt dependencies automatically
--force            Reinstall even when the recorded version matches
--proxy URL        Route all downloads through this HTTP(S) proxy
--install-url URL  Store URL used by the antigravity-linux update command
--status           Show installed helper-managed apps and versions
--print-downloads  Print resolved official Google tarball URLs
--uninstall        Remove helper-managed installation
```

## What it installs

| Component | Path |
|---|---|
| Antigravity 2.0 | `/opt/antigravity` |
| Antigravity IDE | `/opt/antigravity-ide` |
| Launchers | `/usr/local/bin/antigravity`, `/usr/local/bin/antigravity-ide` |
| Update helper | `/usr/local/bin/antigravity-linux` |
| App menu entries | `/usr/share/applications/antigravity*.desktop` |
| Icons | `/usr/share/icons/hicolor/512x512/apps/` |
| Nautilus extension (IDE) | `/usr/share/nautilus-python/extensions/open-in-antigravity-ide.py` |

The Electron/Chromium sandbox is preserved (`chrome-sandbox` set to `root:root`, mode `4755`); no `--no-sandbox` launchers.

## Requirements

- x86_64 or ARM64 Linux, `glibc >= 2.28` (e.g. Ubuntu 20.04, Debian 10, Fedora 36, RHEL 8)
- Debian/Ubuntu (`apt-get`) installs dependencies automatically. Elsewhere, have `bash`, `curl`, `tar`, `python3`, `desktop-file-utils` and `xdg-utils` installed and use `--no-apt`. Nautilus integration also needs `python3-nautilus`.

## License

MIT. See [LICENSE](LICENSE).
