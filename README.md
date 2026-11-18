# Antigravity Linux Installer

One-command installer/updater for **Google Antigravity 2.0** and **Antigravity IDE** on Linux, using Google's official tarballs.

> Community helper. Not affiliated with, endorsed by, or supported by Google. It does not mirror or modify Antigravity: the latest official tarball is resolved from <https://antigravity.google/download> at install time.

## Install

One script does everything. Download it from the latest release, check it, and run it with `sudo`:

```bash
curl -fsSLO https://github.com/ongtungduong/antigravity-linux-installer/releases/latest/download/antigravity-linux
curl -fsSLO https://github.com/ongtungduong/antigravity-linux-installer/releases/latest/download/SHA256SUMS
sha256sum -c SHA256SUMS
sudo bash antigravity-linux install
```

Choose what to install by adding an option after `install`:

| Goal | Command |
|---|---|
| Antigravity 2.0 desktop app only (default) | `sudo bash antigravity-linux install` |
| Antigravity IDE only | `sudo bash antigravity-linux install --ide` |
| Both | `sudo bash antigravity-linux install --all` |
| Behind a proxy | `sudo bash antigravity-linux install --all --proxy http://HOST:PORT` |

See [Options](#options) for the rest (`--cli`, `--force`, `--no-nautilus`, ...). You can also run it without `sudo` and it will ask for it itself.

The script keeps a copy in `/usr/local/bin/antigravity-linux`, so after the first run you can delete the download and use `antigravity-linux ...` for everything below.

`--proxy http://user:pass@host` credentials are visible in the process list while it runs.

## Manage

All commands below ask for `sudo` themselves where needed.

**Update everything (desktop app + IDE)**

```bash
antigravity-linux update --all
```

`update` looks up the latest release of this script, downloads `antigravity-linux` and `SHA256SUMS` from it, and replaces the installed copy **only if the checksum matches and the file is valid shell**. It then installs/updates the apps with the new copy. If the script is already the latest it goes straight to the apps, and an app whose version matches Google's current one is not downloaded again. `apt` is only touched when a dependency is missing.

**Nothing new means nothing to do.** A scheduled workflow ([`google-versions.yml`](.github/workflows/google-versions.yml)) reads Google's download page once a day and publishes the latest versions to [`versions.txt`](https://github.com/ongtungduong/antigravity-linux-installer/blob/google-versions/versions.txt) on the `google-versions` branch, committing only when something changed (so the branch history is a change log). `update` reads that small file first and, if every selected app is already at those versions, stops right there: no `apt`, no Google page, no download. The list is only used to skip work. What gets installed is always resolved from Google's page at install time, and if the list is unreachable `update` simply continues the normal way. It can lag Google by up to a day: use `--no-cache` to ask Google directly. `--force` and `--cli` also skip the shortcut, and `install` never uses it.

**Stay on a reviewed version** by pinning a release tag; without it `update` always takes the latest release:

```bash
ANTIGRAVITY_LINUX_REF=v1.2.3 antigravity-linux update --all
```

**Update the desktop app only**

```bash
update-antigravity
```

**Update the IDE only**

```bash
update-antigravity-ide
```

**Update behind a proxy** (downloads use your proxy variables)

```bash
https_proxy=http://HOST:PORT antigravity-linux update --all
```

**Show installed apps and versions** (works offline)

```bash
antigravity-linux --status
```

**Show the script version**

```bash
antigravity-linux --version
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
--no-cache         On update, ask Google directly instead of the published version list
--proxy URL        Route all downloads through this HTTP(S) proxy
--status           Show installed helper-managed apps and versions
--print-downloads  Print resolved official Google tarball URLs
--version          Print the version of this script
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

Safety rails:

- The swap into `/opt` is rolled back if it fails, and the helper refuses to replace a directory it did not create (it carries a `.antigravity-linux-version` file). `--uninstall` skips such directories too.
- It will not overwrite a regular file in `/usr/local/bin` that is not a symlink.
- Archives are extracted without their original owner, and files are created with `umask 022` whatever your own umask is.
- Every download has a connect timeout and an overall time limit.

## Requirements

- x86_64 or ARM64 Linux, `glibc >= 2.28` (e.g. Ubuntu 20.04, Debian 10, Fedora 36, RHEL 8)
- Debian/Ubuntu (`apt-get`) installs dependencies automatically. Elsewhere, have `bash`, `curl`, `tar`, `python3`, `desktop-file-utils` and `xdg-utils` installed and use `--no-apt`. Nautilus integration also needs `python3-nautilus`.

## Development

```bash
bash tests/run.sh
```

The suite is offline and needs no root: `curl`, `sudo`, `apt-get` and friends are stubbed, and every install path is redirected into a temporary directory. CI also runs `shellcheck` and resolves the real download URLs from Google. `tools/google-versions.sh` prints the latest versions (what the scheduled workflow publishes); a failed `Google versions` run means Google changed the page layout and the parser in `antigravity-linux` needs updating.

### Releasing

The script reports `dev` in a checkout (`VERSION="dev"`). To release, push a tag from `main`:

```bash
git tag v1.2.3 && git push origin v1.2.3
```

The [release workflow](.github/workflows/release.yml) checks that the tag looks like `vX.Y.Z` and is on `main`, runs the tests, stamps the tag into the script, and publishes a GitHub Release with `antigravity-linux` and `SHA256SUMS`.

## License

MIT. See [LICENSE](LICENSE).
