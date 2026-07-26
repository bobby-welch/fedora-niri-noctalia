# System Checks

Use this guide when `ujust system-audit` reports a failure or when a specific
subsystem needs deeper inspection.

## Routine audit

```fish
ujust system-audit
```

The audit is read-only and checks the deployment, failed user units, Niri,
Noctalia, SSH, chezmoi, rclone, and the local BlueBuild repository. Warnings are
informational; failures require attention.

## Deployment

Inspect the current, staged, and rollback deployments:

```fish
rpm-ostree status
```

For management operations and rollback:

```fish
sudo bootc status
```

The expected image is:

```text
ghcr.io/bobby-welch/fedora-niri-noctalia:latest
```

Host package selection belongs in `recipes/recipe.yml`. Avoid routine `dnf
install`, `dnf upgrade`, or ad hoc package layering.

## User services

```fish
systemctl --user --failed --no-pager
systemctl --user list-unit-files --no-pager \
    | rg '^(niri|ssh-agent|rclone)'
```

Expected policy:

- `ssh-agent.socket` is enabled;
- `rclone-hourly-sync.timer` is enabled only on the designated writer;
- the rclone service and notification service are static units.

## Niri and Noctalia

```fish
niri validate
noctalia config validate
pgrep -a noctalia
noctalia msg status
noctalia msg theme-mode-get
```

Noctalia is launched by Niri. A separate Noctalia systemd service is not
expected.

Test the launcher and lock screen:

```fish
noctalia msg panel-toggle launcher
noctalia msg session lock
```

## Theme and portal integration

```fish
printf '%s\n' '=== Noctalia mode ==='
noctalia msg theme-mode-get

printf '\n%s\n' '=== GNOME appearance ==='
gsettings get org.gnome.desktop.interface color-scheme
gsettings get org.gnome.desktop.interface gtk-theme

printf '\n%s\n' '=== Appearance portal ==='
gdbus call \
    --session \
    --dest org.freedesktop.portal.Desktop \
    --object-path /org/freedesktop/portal/desktop \
    --method org.freedesktop.portal.Settings.Read \
    org.freedesktop.appearance \
    color-scheme
```

Inspect portal services and policy:

```fish
systemctl --user --no-pager --type=service \
    | rg 'xdg-desktop-portal'

cat ~/.config/xdg-desktop-portal/portals.conf
```

Restart portals only while troubleshooting:

```fish
systemctl --user restart \
    xdg-desktop-portal.service \
    xdg-desktop-portal-gnome.service \
    xdg-desktop-portal-gtk.service
```

## SSH and GitHub

```fish
systemctl --user status ssh-agent.socket \
    --no-pager \
    --lines=0

echo $SSH_AUTH_SOCK

ssh -G github.com 2>/dev/null \
    | rg '^(hostname|user|identityfile|identitiesonly|'\
'addkeystoagent|forwardagent) '

ssh -T git@github.com
```

GitHub intentionally returns status `1` after successful authentication because
it does not provide shell access. Judge the test by its message.

See [SSH and GitHub Setup](ssh-github.md) for recovery.

## Chezmoi and age

Run the dedicated audit:

```fish
chezmoi-audit
```

Inspect a failure with:

```fish
chezmoi status
chezmoi diff
git -C ~/.local/share/chezmoi status
```

Verify the age identity only when encrypted operations fail:

```fish
stat -c '%A %a %U:%G %n' \
    ~/.config/age/key.txt

age-keygen -y ~/.config/age/key.txt
```

Expected recipient:

```text
age1gdv6nj37ekn2v3r7pw907ujvzhujgeghnsqw8umeyk0tm0v38y3sg542zj
```

See [Chezmoi Setup and Workflow](chezmoi.md) for recovery.

## rclone

```fish
rclone-sync-status

systemctl --user list-timers \
    rclone-hourly-sync.timer \
    --all \
    --no-pager

journalctl --user \
    -u rclone-hourly-sync.service \
    -n 100 \
    --no-pager
```

A completed oneshot service is normally `inactive (dead)` with a successful
result. See [rclone Setup](rclone.md) before changing writer state or retrying a
failed synchronization.

## Flatpaks

```fish
flatpak list --system --app
flatpak list --user --app
flatpak override --show
```

Avoid installing the same application in both scopes. Image-managed graphical
applications should remain system Flatpaks.

Inspect one application:

```fish
flatpak info <application-id>
flatpak override --show <application-id>
```

## Distrobox and workstation tools

```fish
distrobox list
command -v markdownlint-cli2
command -v harper-ls
command -v cloudflare-speed-cli
```

Restore or update them with:

```fish
ujust setup-node-tools
ujust update-markdownlint
ujust update-harper
ujust update-cloudflare-speed-cli
```

## Neovim

```fish
nvim --version | head -n 3
nvim --headless '+checkhealth' '+qa'
```

For a narrower check, open Neovim and run `:checkhealth` for the affected
provider or plugin.

## Printing

Check the persistent CUPS queue and the physical printer:

```fish
printer-status
lpstat -t
```

Inspect the underlying services only while troubleshooting:

```fish
systemctl status \
    cups.socket \
    cups.path \
    avahi-daemon.service \
    --no-pager

ippfind -T 5 --ls
```

`cups.service` may be disabled because CUPS is socket-activated.

## Audio

```fish
systemctl --user --no-pager --type=service \
    | rg 'pipewire|wireplumber'

wpctl status
```

Noctalia controls MPRIS players directly; no separate media-routing daemon is
required.

## Recent errors

```fish
journalctl --user -p warning..alert -b --no-pager
sudo journalctl -p warning..alert -b --no-pager
```

Review messages in context. Warnings are not automatically defects.

## Final verification

```fish
ujust system-audit
```

The summary should report no failures.
