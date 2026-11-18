# Antigravity for Linux

One-command installer/updater for **Google Antigravity 2.0** and **Antigravity IDE** on Linux, using Google's official tarballs.

> Community helper. Not affiliated with, endorsed by, or supported by Google. It does not mirror or modify Antigravity: the latest official tarball is resolved from <https://antigravity.google/download> at install time.

## Install

The script asks for `sudo` itself. Pick one:

**Antigravity 2.0 desktop app only** (default)

```bash
curl -fsSL https://raw.githubusercontent.com/ongtungduong/antigravity-for-linux/main/install.sh | bash
```

**Antigravity IDE only**

```bash
curl -fsSL https://raw.githubusercontent.com/ongtungduong/antigravity-for-linux/main/install.sh | bash -s -- --ide
```

**Both (desktop app + IDE)**

```bash
curl -fsSL https://raw.githubusercontent.com/ongtungduong/antigravity-for-linux/main/install.sh | bash -s -- --all
```

**Behind a proxy** (add `--proxy` to any of the above)

```bash
curl -fsSL https://raw.githubusercontent.com/ongtungduong/antigravity-for-linux/main/install.sh | bash -s -- --all --proxy http://HOST:PORT
```

Flags go after `bash -s --`; see [Options](#options) for the rest (`--cli`, `--force`, `--no-nautilus`, ...).

How it works: `install.sh` is a short bootstrap. It downloads the `antigravity-linux` helper and runs `antigravity-linux install`, which re-runs itself under `sudo`, installs the apps, and keeps itself in `/usr/local/bin` for later updates. To review first, read [`install.sh`](install.sh) and [`antigravity-linux`](antigravity-linux), or download the helper and run `bash antigravity-linux install --all`. To install a reviewed version, pin it: `curl -fsSL https://raw.githubusercontent.com/ongtungduong/antigravity-for-linux/<tag>/install.sh | ANTIGRAVITY_LINUX_REF=<tag> bash`.

`--proxy http://user:pass@host` credentials are visible in the process list while it runs.

## Manage

All commands below ask for `sudo` themselves where needed.

**Update everything (desktop app + IDE)**

```bash
antigravity-linux update --all
```

`update` first downloads the latest helper (rejecting it if it is not valid shell), then installs.

**Update the desktop app only**

```bash
update-antigravity
```

**Update the IDE only**

```bash
update-antigravity-ide
```

**Update behind a proxy** (the helper downloads itself through your proxy variables)

```bash
https_proxy=http://HOST:PORT antigravity-linux update --all
```

**Show installed apps and versions** (works offline)

```bash
antigravity-linux --status
```

**Uninstall** (works offline; removes helper-managed files, keeps user settings)

```bash
antigravity-linux --uninstall
```

Any [option](#options) can be added to `antigravity-linux update`, e.g. `--force` to reinstall the current version.

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
