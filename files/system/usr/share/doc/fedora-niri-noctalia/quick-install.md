# Quick Installation

Use this guide for a normal rebuild from the Fedora Niri Noctalia installer ISO.
Detailed recovery and troubleshooting are covered in the subsystem guides.

> **Important**
>
> Do not enable rclone until the local data has been restored, inspected, and
> verified with dry runs. Only one laptop may be the active rclone writer.

## 1. Install and boot

Boot the installer USB, complete the Fedora installer, remove the USB drive, and
boot the installed system.

Verify the workstation:

```fish
ujust system-audit
```

During initial setup, `SKIP` results are expected for components that have not
been configured yet.

## 2. Set the hostname and connect

```fish
hostnamectl
nmcli general status
nmcli device status
```

Set the hostname if needed, then reboot:

```fish
sudo hostnamectl hostname frost
systemctl reboot
```

## 3. Sign in to 1Password

Sign in and locate the document named:

```text
Chezmoi age identity key
```

The age identity is required before chezmoi can decrypt the managed rclone
configuration.

## 4. Create the GitHub SSH key

Enable the SSH-agent socket and create a device-specific key:

```fish
systemctl --user enable --now ssh-agent.socket

mkdir -p ~/.ssh
chmod 700 ~/.ssh

ssh-keygen \
    -t ed25519 \
    -C "bobby@$(hostname)" \
    -f ~/.ssh/id_ed25519
```

Use a strong passphrase and save it in 1Password. Add
`~/.ssh/id_ed25519.pub` to GitHub as an authentication key, then test:

```fish
ssh -T git@github.com
```

A successful test recognizes the GitHub account and says that shell access is
not provided. Exit status `1` is normal for this test.

For details, see [SSH and GitHub Setup](ssh-github.md).

## 5. Restore the age identity

Restore the 1Password document to:

```text
~/.config/age/key.txt
```

Then secure and verify it:

```fish
mkdir -p ~/.config/age
chmod 600 ~/.config/age/key.txt
age-keygen -y ~/.config/age/key.txt
```

Expected recipient:

```text
age1gdv6nj37ekn2v3r7pw907ujvzhujgeghnsqw8umeyk0tm0v38y3sg542zj
```

Stop if it differs.

## 6. Apply the dotfiles

```fish
chezmoi init --apply \
    git@github.com:bobby-welch/dotfiles.git

systemctl --user daemon-reload
systemctl --user enable --now ssh-agent.socket
exec fish
```

Verify the result:

```fish
chezmoi-audit
```

The audit should report no item requiring attention.

For details, see [Chezmoi Setup and Workflow](chezmoi.md).

## 7. Complete workstation setup

Restore the workstation tools that are intentionally installed outside the
immutable image:

```fish
ujust setup-node-tools
ujust update-harper
ujust update-cloudflare-speed-cli
```

Verify them:

```fish
command -v markdownlint-cli2
command -v harper-ls
command -v cloudflare-speed-cli
```

Each command should print a path.

Configure Noctalia's native idle behaviors for locking and monitor power-off,
then test the lock screen:

```fish
noctalia msg session lock
```

Run an interim check:

```fish
ujust system-audit
```

Resolve any unexpected failure before continuing.

## 8. Configure the printer

The Brother printer uses a permanent driverless IPP Everywhere queue. Confirm
that the printer is advertised on the local network:

```fish
ippfind -T 5 --ls
```

Expected endpoint:

```text
ipp://BRWF8DA0C603CA2.local:631/ipp/print
```

Create the persistent queue and make it the system default:

```fish
sudo lpadmin \
    -p Brother_HL_L2340D \
    -E \
    -v 'ipp://BRWF8DA0C603CA2.local:631/ipp/print' \
    -m everywhere

sudo lpadmin -d Brother_HL_L2340D
```

Do not enable `cups.service` directly or install a legacy Brother driver unless
driverless IPP fails.

Verify the queue, default, and printer connection:

```fish
lpstat -t
printer-status
```

Print the standard CUPS test page:

```fish
lp /usr/share/cups/data/testprint
```

## 9. Restore accounts and application data

Sign in to the required applications and restore their local data. Install
additional applications deliberately, and avoid duplicate user and system
Flatpak installations.

## 10. Restore synchronized data

Verify the rclone remotes:

```fish
rclone listremotes
rclone about pcloud:
rclone lsf eBooks: --max-depth 1 | head -n 20
```

Create the local directories and restore from the remote:

```fish
mkdir -p ~/Documents ~/Pictures ~/eBooks

rclone copy pcloud:Documents ~/Documents --progress
rclone copy pcloud:Pictures ~/Pictures --progress
rclone copy eBooks: ~/eBooks --progress
```

Inspect the restored files carefully. These verified local directories will
become the authoritative source for the hourly one-way sync.

## 11. Dry-run the one-way sync

```fish
rclone sync \
    ~/Documents \
    pcloud:Documents \
    --dry-run \
    --combined=- \
    --retries=1 \
    --log-level=ERROR

rclone sync \
    ~/Pictures \
    pcloud:Pictures \
    --dry-run \
    --combined=- \
    --retries=1 \
    --log-level=ERROR

rclone sync \
    ~/eBooks \
    eBooks: \
    --dry-run \
    --combined=- \
    --retries=1 \
    --log-level=ERROR
```

Review every proposed upload, replacement, and deletion. Do not continue if
anything is unexpected.

For recovery and troubleshooting, see [rclone Setup](rclone.md).

## 12. Enable this laptop as the rclone writer

Create the machine-local writer marker:

```fish
mkdir -p ~/.config/rclone-sync

printf '%s\n' \
    "Primary rclone writer: $(hostname)" \
    > ~/.config/rclone-sync/enabled

chmod 600 ~/.config/rclone-sync/enabled
```

Run one manual sync and verify success:

```fish
systemctl --user start \
    rclone-hourly-sync.service

rclone-sync-status
```

Proceed only when the last result is `SUCCESS`, then enable the timer:

```fish
systemctl --user enable --now \
    rclone-hourly-sync.timer

rclone-sync-status
```

## 13. Clone the image repository

```fish
mkdir -p ~/.local/src

git clone \
    git@github.com:bobby-welch/fedora-niri-noctalia.git \
    ~/.local/src/fedora-niri-noctalia
```

Skip the clone if the repository already exists.

## 14. Final check

```fish
ujust system-audit
```

The final summary should report no failures. See [System
Checks](system-checks.md) for targeted diagnostics when an audit item fails.
