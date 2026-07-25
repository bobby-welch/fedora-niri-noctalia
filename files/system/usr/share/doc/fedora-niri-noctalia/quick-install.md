# Quick Installation

Use this guide for a normal rebuild from the Fedora Niri Noctalia installer ISO.

Stop and use the [detailed installation and recovery guide](install.md) whenever
a result differs from the expected outcome. Do not enable rclone until the local
data has been restored and reviewed.

## 1. Install and boot

Boot the installer USB, complete the Fedora installer, remove the USB drive, and
boot the installed system.

Verify the image:

```fish
sudo bootc status
```

Expected image:

```text
ghcr.io/bobby-welch/fedora-niri-noctalia:latest
```

## 2. Set the hostname and connect

```fish
hostnamectl
nmcli general status
nmcli device status
```

Set the hostname if needed:

```fish
sudo hostnamectl hostname frost
systemctl reboot
```

## 3. Sign in to 1Password

Sign in and locate:

```text
Chezmoi age identity key
```

You will need it before applying the dotfiles.

## 4. Create the GitHub SSH key

```fish
systemctl --user enable --now ssh-agent.socket

mkdir -p ~/.ssh
chmod 700 ~/.ssh

ssh-keygen \
    -t ed25519 \
    -C "bobby@$(hostname)" \
    -f ~/.ssh/id_ed25519
```

Use a strong passphrase and save it in 1Password.

Add `~/.ssh/id_ed25519.pub` to GitHub as an authentication key, then test:

```fish
ssh -T git@github.com
```

A successful test recognizes the GitHub account and says shell access is not
provided. Exit status `1` is normal for this test.

For problems, see [SSH and GitHub Setup](ssh-github.md).

## 5. Restore the age identity

Restore the 1Password document to:

```text
~/.config/age/key.txt
```

Then verify it:

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

chezmoi status

git -C ~/.local/share/chezmoi status
```

`chezmoi status` should print nothing, and the Git working tree should be clean.

Reload the systemd user manager and enable the SSH-agent socket:

```fish
systemctl --user daemon-reload
systemctl --user enable --now ssh-agent.socket
```

Start a fresh Fish process so the managed shell configuration is loaded:

```fish
exec fish
```

Noctalia v5 handles MPRIS media selection and can handle locking, monitor
power-off, and suspend through its native services. Do not enable
`playerctld.service` or `swayidle.service` unless you have deliberately chosen
to keep those optional external services.

Do not enable rclone yet.

For problems, see [Chezmoi Setup and Workflow](chezmoi.md).

## 7. Verify the desktop

```fish
niri validate
noctalia config validate
pgrep -a noctalia
noctalia msg status
noctalia msg theme-mode-get
systemctl --user --failed --no-pager
```

Resolve any unexpected failure before continuing.

Configure Noctalia's native idle behaviors for locking and monitor power-off.
The built-in idle behaviors are disabled by default until explicitly enabled.
Test the lock screen with:

```fish
noctalia msg session lock
```

## 8. Restore accounts and personal applications

Sign in to the required applications and restore their local data.

The image-managed Flatpaks are:

```text
io.github.lullabyX.sone
md.obsidian.Obsidian
org.libreoffice.LibreOffice
```

Install other personal applications deliberately and avoid duplicate user and
system Flatpak installations.

## 9. Restore synchronized data

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

## 10. Dry-run the one-way sync

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

Review every proposed upload, replacement, and deletion. Do not proceed if
anything is unexpected.

For recovery or troubleshooting, see [rclone Setup](rclone.md).

## 11. Enable this laptop as the rclone writer

Only one laptop may be active as the writer.

```fish
mkdir -p ~/.config/rclone-sync

printf '%s\n' \
    "Primary rclone writer: $(hostname)" \
    > ~/.config/rclone-sync/enabled

chmod 600 ~/.config/rclone-sync/enabled

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

## 12. Clone the image repository

```fish
mkdir -p ~/.local/src

git clone \
    git@github.com:bobby-welch/fedora-niri-noctalia.git \
    ~/.local/src/fedora-niri-noctalia
```

Skip this command if the repository already exists.

## 13. Final check

```fish
sudo bootc status

chezmoi status

git -C ~/.local/share/chezmoi status

systemctl --user --failed --no-pager

rclone-sync-status
```

For a comprehensive audit, follow [System Health Checks](system-checks.md).
