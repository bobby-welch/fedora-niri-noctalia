# Fedora Niri Noctalia Installation Guide

This is the master checklist for rebuilding the complete system.

Detailed subsystem instructions are kept in separate guides:

- [SSH and GitHub Setup](ssh-github.md)
- [Chezmoi Setup and Workflow](chezmoi.md)
- [rclone Setup](rclone.md)
- [System Health Checks](system-checks.md)

Follow the sections in order. Do not enable rclone until the local data
directories have been restored and verified.

## System design

The system uses:

- Fedora Atomic 44;
- a custom BlueBuild image;
- Niri as the Wayland compositor;
- Noctalia as the desktop shell;
- greetd and tuigreet for login;
- Fish as the interactive shell;
- Alacritty as the terminal;
- Neovim as the editor;
- chezmoi for personal configuration;
- system-level Flatpaks for graphical applications;
- Distrobox for selected development tools;
- rclone for one-way hourly synchronization to pCloud.

The BlueBuild image is:

```text
ghcr.io/bobby-welch/fedora-niri-noctalia:latest
```

Source repository:

```text
git@github.com:bobby-welch/fedora-niri-noctalia.git
```

Dotfiles repository:

```text
git@github.com:bobby-welch/dotfiles.git
```

## 1. Install the BlueBuild image

Use the current documented installation or rebase procedure from the BlueBuild
repository.

After booting the custom image, verify:

```fish
rpm-ostree status
```

The active deployment should reference:

```text
ghcr.io/bobby-welch/fedora-niri-noctalia:latest
```

The active deployment is marked with `●`.

Verify that the system is idle:

```text
State: idle
```

Do not layer ordinary desktop packages manually. Package selection belongs in:

```text
recipes/recipe.yml
```

## 2. Complete first boot

Log in through tuigreet.

The image configures greetd to launch:

```text
niri-session
```

This wrapper establishes the systemd and D-Bus graphical session required by
portals and desktop services.

Confirm the hostname:

```fish
hostnamectl
```

Set the hostname if necessary:

```fish
sudo hostnamectl hostname <hostname>
```

Reboot after changing it:

```fish
systemctl reboot
```

## 3. Verify network access

Check NetworkManager:

```fish
nmcli general status
nmcli device status
```

Confirm internet access:

```fish
ping -c 3 github.com
```

Update the current deployment metadata:

```fish
rpm-ostree status
```

Do not use `dnf upgrade` or `dnf install` for routine host management.

## 4. Sign in to 1Password

Open 1Password and sign in.

The following recovery item is required before chezmoi can apply encrypted
files:

```text
Chezmoi age identity key
```

Do not place the age private key or SSH private key in the Git repository.

## 5. Configure SSH and GitHub

Follow:

[SSH and GitHub Setup](ssh-github.md)

The high-level sequence is:

1. Enable the systemd SSH-agent socket.
2. Generate a new per-device Ed25519 key.
3. Add the public key to GitHub.
4. verify GitHub authentication.
5. confirm the managed SSH configuration after chezmoi is applied.

Enable the SSH agent:

```fish
systemctl --user enable --now ssh-agent.socket
```

Generate a new device key:

```fish
mkdir -p ~/.ssh
chmod 700 ~/.ssh

ssh-keygen \
    -t ed25519 \
    -C "bobby@$(hostname)" \
    -f ~/.ssh/id_ed25519
```

Add the contents of:

```text
~/.ssh/id_ed25519.pub
```

to GitHub as an authentication key.

Test:

```fish
ssh -T git@github.com
```

Do not copy the SSH private key from another laptop.

## 6. Restore the age identity

Restore the 1Password document:

```text
Chezmoi age identity key
```

to:

```text
~/.config/age/key.txt
```

Create the directory if needed:

```fish
mkdir -p ~/.config/age
```

Secure the file:

```fish
chmod 600 ~/.config/age/key.txt
```

Verify its public recipient:

```fish
age-keygen -y ~/.config/age/key.txt
```

Expected value:

```text
age1gdv6nj37ekn2v3r7pw907ujvzhujgeghnsqw8umeyk0tm0v38y3sg542zj
```

Stop if the value differs.

## 7. Initialize chezmoi

Follow:

[Chezmoi Setup and Workflow](chezmoi.md)

Initialize and apply the repository:

```fish
chezmoi init --apply bobby-welch
```

This should:

- clone the dotfiles repository;
- create the local chezmoi configuration;
- decrypt the rclone configuration;
- install the managed files;
- load the managed dconf settings.

Verify:

```fish
chezmoi status
```

A clean result produces no output.

Check the repository:

```fish
git -C ~/.local/share/chezmoi status
```

Expected:

```text
nothing to commit, working tree clean
```

## 8. Restart the shell environment

Start a fresh Fish process:

```fish
exec fish
```

Verify:

```fish
printf 'SHELL=%s\n' $SHELL
printf 'SSH_AUTH_SOCK=%s\n' $SSH_AUTH_SOCK
printf 'XDG_CURRENT_DESKTOP=%s\n' $XDG_CURRENT_DESKTOP
```

Expected SSH-agent socket form:

```text
/run/user/1000/ssh-agent.socket
```

The numeric user ID may differ.

Verify the managed GitHub configuration:

```fish
ssh -G github.com 2>/dev/null \
    | rg '^(hostname|user|identityfile|identitiesonly|addkeystoagent|forwardagent) '
```

Expected essentials:

```text
user git
hostname github.com
identityfile ~/.ssh/id_ed25519
identitiesonly yes
addkeystoagent true
forwardagent no
```

## 9. Reload systemd user units

Chezmoi installs several user units.

Reload them:

```fish
systemctl --user daemon-reload
```

Check for failures:

```fish
systemctl --user --failed --no-pager
```

Enable the general-purpose units:

```fish
systemctl --user enable --now ssh-agent.socket
systemctl --user enable --now playerctld.service
systemctl --user enable --now swayidle.service
```

Do not enable the rclone timer yet.

The rclone timer must remain disabled until local data has been restored and
reviewed.

## 10. Verify Niri and Noctalia

Validate the Niri configuration:

```fish
niri validate
```

Noctalia is launched directly by Niri through:

```kdl
spawn-at-startup "noctalia"
```

A separate Noctalia systemd service is not expected.

Verify Noctalia:

```fish
pgrep -a noctalia
noctalia msg status
noctalia msg theme-mode-get
```

Test the launcher:

```fish
noctalia msg panel-toggle launcher
```

## 11. Verify portals

Check the active portal services:

```fish
systemctl --user --no-pager \
    --type=service \
    | rg 'xdg-desktop-portal'
```

Expected services include:

```text
xdg-desktop-portal.service
xdg-desktop-portal-gnome.service
xdg-desktop-portal-gtk.service
```

Inspect the managed configuration:

```fish
cat ~/.config/xdg-desktop-portal/portals.conf
```

Expected:

```ini
[preferred]
default=gnome;gtk
org.freedesktop.impl.portal.FileChooser=gtk
org.freedesktop.impl.portal.Notification=gtk
org.freedesktop.impl.portal.Secret=gnome-keyring
```

## 12. Verify theme switching

Check the current state:

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

Toggle the mode:

```fish
noctalia msg theme-mode-toggle
```

Repeat the checks and verify that the GTK and portal values change.

## 13. Verify system Flatpaks

The BlueBuild recipe installs its default Flatpaks at system scope.

List them:

```fish
flatpak list --app \
    --columns=application,installation,name \
    | sort
```

Image-managed applications currently include:

```text
io.github.lullabyX.sone
md.obsidian.Obsidian
org.libreoffice.LibreOffice
```

The image also provides the required GTK 3 theme extensions.

Each image-managed application should appear under:

```text
system
```

Check for duplicates:

```fish
flatpak list --app \
    --columns=application,installation \
    | sort
```

An application appearing under both `user` and `system` should be reviewed.

Do not use `--delete-data` when removing a duplicate unless its local
application data should also be erased.

## 14. Install additional graphical applications

Install personal graphical applications that are not currently part of the image
recipe.

Current applications may include:

```text
app.zen_browser.zen
com.mastermindzh.tidal-hifi
com.onepassword.OnePassword
com.sigil_ebook.Sigil
com.spotify.Client
org.mozilla.firefox
```

Decide whether each application belongs permanently in the BlueBuild recipe or
should remain a deliberate manual installation.

Prefer system scope for centrally managed applications:

```fish
flatpak install --system flathub <application-id>
```

Avoid installing the same application at both user and system scope.

## 15. Verify Flatpak overrides

The following user overrides are intentional.

SONE:

```fish
flatpak override --user --show \
    io.github.lullabyX.sone
```

Expected:

```ini
[Environment]
WEBKIT_DISABLE_COMPOSITING_MODE=

[Context]
unset-environment=WEBKIT_DISABLE_COMPOSITING_MODE;
```

Obsidian:

```fish
flatpak override --user --show \
    md.obsidian.Obsidian
```

Expected:

```ini
[Context]
sockets=!x11;wayland;
```

The overrides may need to be recreated on a fresh machine if they are not
managed elsewhere.

## 16. Set up Distrobox tools

The image contains a Distrobox definition for Node-based tools.

Create the Node tools container and export its commands:

```fish
ujust setup-node-tools
```

The container installs and exports:

```text
markdownlint-cli2
```

Verify:

```fish
command -v markdownlint-cli2
markdownlint-cli2 --version
```

Install or update Harper:

```fish
ujust update-harper
```

Verify:

```fish
command -v harper-ls
harper-ls --version
```

Install or update Cloudflare Speed CLI when desired:

```fish
ujust update-cloudflare-speed-cli
```

List the custom commands:

```fish
ujust --list \
    | rg 'cloudflare|harper|node-tools'
```

## 17. Verify Neovim

Start Neovim:

```fish
nvim
```

Verify:

- no startup errors;
- the expected color scheme loads;
- plugins load;
- LSP clients start where expected;
- Markdown formatting and linting tools are available.

Run:

```vim
:checkhealth
```

Review actual errors. Informational warnings do not always require changes.

## 18. Restore application data and accounts

Sign in to applications and restore local data as needed.

Examples include:

- browser profiles;
- Obsidian vaults;
- music applications;
- Sigil preferences;
- LibreOffice preferences;
- password-manager integration.

Do not store application session tokens in the dotfiles repository.

## 19. Restore synchronized directories

Before enabling rclone, ensure these directories exist:

```text
~/Documents
~/Pictures
~/eBooks
```

Check:

```fish
for dir in ~/Documents ~/Pictures ~/eBooks
    if test -d $dir
        printf 'OK: %s\n' $dir
    else
        printf 'MISSING: %s\n' $dir
    end
end
```

These directories must contain the intended authoritative local data.

Do not create the rclone primary-writer marker merely to make the status command
look healthy.

## 20. Verify rclone without enabling it

Follow:

[rclone Setup](rclone.md)

Verify the remotes:

```fish
rclone listremotes
```

Expected:

```text
pcloud:
eBooks:
```

Test pCloud:

```fish
rclone about pcloud:
```

Test the encrypted eBooks remote:

```fish
rclone lsf eBooks: \
    --max-depth 1 \
    | head -n 20
```

Check the role:

```fish
rclone-sync-status
```

Before activation it should report:

```text
Rclone role: DISABLED
```

## 21. Perform rclone dry runs

Run a dry run for each synchronized directory.

Documents:

```fish
rclone sync \
    ~/Documents \
    pcloud:Documents \
    --dry-run \
    --combined=- \
    --retries=1 \
    --log-level=ERROR
```

Pictures:

```fish
rclone sync \
    ~/Pictures \
    pcloud:Pictures \
    --dry-run \
    --combined=- \
    --retries=1 \
    --log-level=ERROR
```

eBooks:

```fish
rclone sync \
    ~/eBooks \
    eBooks: \
    --dry-run \
    --combined=- \
    --retries=1 \
    --log-level=ERROR
```

Review every proposed upload, replacement, and deletion.

Do not proceed if the dry runs are unexpected.

## 22. Activate this laptop as the rclone writer

Only one laptop may have the primary-writer marker and enabled timer.

Create the marker:

```fish
mkdir -p ~/.config/rclone-sync

printf '%s\n' \
    "Primary rclone writer: $(hostname)" \
    > ~/.config/rclone-sync/enabled

chmod 600 ~/.config/rclone-sync/enabled
```

Run one manual sync:

```fish
systemctl --user start \
    rclone-hourly-sync.service
```

Check:

```fish
rclone-sync-status
```

Proceed only if it reports:

```text
Last result: SUCCESS
```

Enable the hourly timer:

```fish
systemctl --user enable --now \
    rclone-hourly-sync.timer
```

Verify:

```fish
systemctl --user list-timers \
    rclone-hourly-sync.timer \
    --all \
    --no-pager
```

## 23. Clone the BlueBuild source repository

The repository is useful for maintaining the image.

Create the source directory:

```fish
mkdir -p ~/.local/src
```

Clone:

```fish
git clone \
    git@github.com:bobby-welch/fedora-niri-noctalia.git \
    ~/.local/src/fedora-niri-noctalia
```

Verify:

```fish
git -C ~/.local/src/fedora-niri-noctalia status
```

Expected:

```text
nothing to commit, working tree clean
```

The main recipe is:

```text
recipes/recipe.yml
```

GitHub Actions builds the image:

- daily at 06:00 UTC;
- when relevant repository changes are pushed;
- when manually triggered.

Documentation-only changes do not trigger a rebuild.

## 24. Final validation

Follow:

[System Health Checks](system-checks.md)

At minimum, run:

```fish
rpm-ostree status

chezmoi status

git -C ~/.local/share/chezmoi status

git -C ~/.local/src/fedora-niri-noctalia status

systemctl --user --failed --no-pager

systemctl --user status ssh-agent.socket \
    --no-pager \
    --lines=0

ssh -T git@github.com

niri validate

noctalia msg status

rclone-sync-status
```

A completed installation should have:

- the expected BlueBuild deployment;
- a clean chezmoi state;
- clean Git repositories;
- no unexpected failed user units;
- working GitHub authentication;
- a valid Niri configuration;
- a responsive Noctalia shell;
- functioning portals and theme switching;
- one system installation of each image-managed Flatpak;
- working development tools;
- successful or intentionally disabled rclone synchronization.

## Ongoing maintenance

### Update the system

BlueBuild images are rebuilt through GitHub Actions and delivered as Atomic
deployments.

Check:

```fish
rpm-ostree status
```

Reboot when a new deployment has been staged:

```fish
systemctl reboot
```

### Update dotfiles

Review-first workflow:

```fish
git -C ~/.local/share/chezmoi pull --ff-only
chezmoi diff
chezmoi apply
```

### Update the image recipe

Edit:

```text
~/.local/src/fedora-niri-noctalia/recipes/recipe.yml
```

Then:

```fish
git -C ~/.local/src/fedora-niri-noctalia diff --check
git -C ~/.local/src/fedora-niri-noctalia status
```

Commit and push only after reviewing the change.

### Check system health

Periodically follow:

[System Health Checks](system-checks.md)

### Check synchronization

```fish
rclone-sync-status
```

Review failures promptly so the local and remote copies do not diverge
unnoticed.
