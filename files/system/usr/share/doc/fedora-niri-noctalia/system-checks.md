# System Health Checks

This guide verifies that the Fedora Atomic/BlueBuild, Niri, Noctalia, chezmoi,
SSH, Flatpak, portal, and rclone setup is working correctly.

Use it after:

- a fresh installation;
- a BlueBuild update;
- applying major dotfile changes;
- moving the setup to another laptop;
- troubleshooting unexpected desktop behavior.

## Quick health check

Run:

```fish
sudo bootc status

chezmoi status

git -C ~/.local/share/chezmoi status

systemctl --user --failed --no-pager

rclone-sync-status
```

A healthy system should have:

- the expected BlueBuild image booted;
- no chezmoi differences;
- a clean dotfiles repository;
- no unexpected failed user units;
- a successful or deliberately disabled rclone status.

## 1. Verify the BlueBuild deployment

Inspect the current deployment:

```fish
sudo bootc status
```

The output should identify the expected booted image:

```text
● Booted image: ghcr.io/bobby-welch/fedora-niri-noctalia:latest
```

The digest and version identify the exact image currently running.

A previous deployment may appear as:

```text
Rollback image:
```

A downloaded update that has not yet been activated appears as a staged
deployment.

Check for a newer image without downloading its full layers:

```fish
sudo bootc upgrade --check
```

Automatic bootc updates are disabled on this image, so updates are applied
manually.

## 2. Verify core commands

```fish
for cmd in \
    niri \
    noctalia \
    alacritty \
    fish \
    nvim \
    chezmoi \
    rclone \
    age \
    git \
    rg \
    fd \
    fzf \
    bat \
    tmux

    if command -q $cmd
        printf 'OK      %s -> %s\n' $cmd (command -s $cmd)
    else
        printf 'MISSING %s\n' $cmd
    end
end
```

Every command should report `OK`.

A missing command usually means the BlueBuild image recipe or deployment needs
attention. Avoid installing host packages manually unless the package is
intentionally meant to be layered.

## 3. Verify chezmoi

```fish
chezmoi status
```

A clean result produces no output.

Check the repository:

```fish
git -C ~/.local/share/chezmoi status
```

Expected result:

```text
nothing to commit, working tree clean
```

Verify the configured paths and age encryption:

```fish
chezmoi source-path

chezmoi data \
    | rg '"(sourceDir|configFile|encryption|identity|recipient)"'
```

Expected paths include:

```text
/home/bobby/.local/share/chezmoi
/home/bobby/.config/chezmoi/chezmoi.toml
/home/bobby/.config/age/key.txt
```

## 4. Verify the age identity

```fish
stat -c '%A %a %U:%G %n' \
    ~/.config/age/key.txt
```

Expected mode:

```text
600
```

Verify the public recipient:

```fish
age-keygen -y ~/.config/age/key.txt
```

Expected recipient:

```text
age1gdv6nj37ekn2v3r7pw907ujvzhujgeghnsqw8umeyk0tm0v38y3sg542zj
```

Do not continue with encrypted chezmoi operations if this value differs.

## 5. Verify SSH and GitHub authentication

Check the SSH-agent socket:

```fish
systemctl --user status ssh-agent.socket \
    --no-pager \
    --lines=0
```

It should be enabled and active.

Check the environment:

```fish
echo $SSH_AUTH_SOCK
```

Expected form:

```text
/run/user/1000/ssh-agent.socket
```

Verify the GitHub SSH configuration:

```fish
ssh -G github.com 2>/dev/null \
    | rg '^(hostname|user|identityfile|identitiesonly|'\
'addkeystoagent|forwardagent) '
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

Test GitHub authentication:

```fish
ssh -T git@github.com
```

GitHub should recognize the account and report that shell access is not
provided.

## 6. Verify user services

Check for failures:

```fish
systemctl --user --failed --no-pager
```

Expected result:

```text
0 loaded units listed.
```

List important user units:

```fish
systemctl --user list-unit-files --no-pager \
    | rg '^(niri|playerctld|swayidle|ssh-agent|rclone)'
```

Expected enabled units include:

```text
playerctld.service
swayidle.service
ssh-agent.socket
rclone-hourly-sync.timer
```

The rclone service and notification service are static units and do not need to
be enabled directly.

## 7. Verify Niri

Check the running compositor:

```fish
systemctl --user status niri.service \
    --no-pager \
    --lines=0
```

It should report:

```text
Active: active (running)
```

Validate the Niri configuration:

```fish
niri validate
```

A valid configuration should produce no error.

Confirm the active session:

```fish
printf 'XDG_CURRENT_DESKTOP=%s\n' $XDG_CURRENT_DESKTOP
printf 'WAYLAND_DISPLAY=%s\n' $WAYLAND_DISPLAY
```

Expected desktop:

```text
niri
```

## 8. Verify Noctalia

Noctalia is intentionally launched by Niri with:

```kdl
spawn-at-startup "noctalia"
```

A separate Noctalia systemd user service is not expected.

Check the process:

```fish
pgrep -a noctalia
```

Check the shell connection:

```fish
noctalia msg status
```

Check the active theme mode:

```fish
noctalia msg theme-mode-get
```

Test the launcher:

```fish
noctalia msg panel-toggle launcher
```

The launcher should open and close normally.

## 9. Verify theme switching

Record the current portal and GTK state:

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

Expected behavior:

- dark mode reports `prefer-dark`;
- light mode reports `prefer-light`;
- the portal value changes with the selected mode;
- GTK 4 applications should follow the portal;
- some applications may require a restart.

Toggle the mode:

```fish
noctalia msg theme-mode-toggle
```

Then repeat the checks.

## 10. Verify portals

Check active portal services:

```fish
systemctl --user --no-pager \
    --type=service \
    | rg 'xdg-desktop-portal'
```

Expected active services include:

```text
xdg-desktop-portal.service
xdg-desktop-portal-gnome.service
xdg-desktop-portal-gtk.service
```

Inspect the configured portal preference:

```fish
cat ~/.config/xdg-desktop-portal/portals.conf
```

Expected configuration:

```ini
[preferred]
default=gnome;gtk
org.freedesktop.impl.portal.FileChooser=gtk
org.freedesktop.impl.portal.Notification=gtk
org.freedesktop.impl.portal.Secret=gnome-keyring
```

Restart portals only when troubleshooting:

```fish
systemctl --user restart \
    xdg-desktop-portal.service \
    xdg-desktop-portal-gnome.service \
    xdg-desktop-portal-gtk.service
```

## 11. Verify audio and media integration

Check PipeWire and WirePlumber:

```fish
systemctl --user --no-pager \
    --type=service \
    | rg 'pipewire|wireplumber'
```

Check playerctld:

```fish
systemctl --user status playerctld.service \
    --no-pager \
    --lines=0
```

List media players:

```fish
playerctl --list-all
```

Check default audio devices:

```fish
wpctl status
```

Noctalia media and volume controls should respond through its configured
keybindings.

## 12. Verify idle and lock behavior

Check swayidle:

```fish
systemctl --user status swayidle.service \
    --no-pager \
    --lines=0
```

It should be enabled and active during the Niri session.

Inspect the unit:

```fish
systemctl --user cat swayidle.service
```

Expected behavior includes:

- locking after the configured idle period;
- powering off monitors after the longer timeout;
- locking before sleep.

Test locking manually through Noctalia:

```fish
noctalia msg session lock
```

## 13. Verify Flatpaks

List installed applications by installation:

```fish
flatpak list --app \
    --columns=application,installation,name \
    | sort
```

The intended applications should appear once under the `system` installation.

Image-managed applications currently include:

```text
io.github.lullabyX.sone
md.obsidian.Obsidian
org.libreoffice.LibreOffice
```

Additional personal applications may also be installed at system scope, but
their presence is not required for the BlueBuild image itself to be healthy.

Check for duplicate app installations:

```fish
flatpak list --app \
    --columns=application,installation \
    | sort
```

An application appearing under both `user` and `system` is usually an old
duplicate and should be reviewed.

Do not use `--delete-data` when removing duplicate installations unless
application data should also be erased.

## 14. Verify Flatpak overrides

Show the SONE override:

```fish
flatpak override --user --show \
    io.github.lullabyX.sone
```

Expected result:

```ini
[Environment]
WEBKIT_DISABLE_COMPOSITING_MODE=

[Context]
unset-environment=WEBKIT_DISABLE_COMPOSITING_MODE;
```

Show the Obsidian override:

```fish
flatpak override --user --show \
    md.obsidian.Obsidian
```

Expected result:

```ini
[Context]
sockets=!x11;wayland;
```

List all user overrides:

```fish
flatpak override --user --show
```

Review unexpected global overrides carefully.

## 15. Verify Neovim

Check the version:

```fish
nvim --version | head
```

Start Neovim without opening a file:

```fish
nvim
```

Verify:

- no startup errors;
- colors and light/dark mode are correct;
- plugins load;
- LSP starts where expected;
- Markdown tooling works.

Run the built-in health check:

```vim
:checkhealth
```

Review errors rather than trying to eliminate every informational warning.

## 16. Verify Fish and shell tools

Start a clean Fish session:

```fish
exec fish
```

Verify Starship:

```fish
type -a starship
```

Check important environment values:

```fish
printf 'SHELL=%s\n' $SHELL
printf 'SSH_AUTH_SOCK=%s\n' $SSH_AUTH_SOCK
printf 'XDG_CURRENT_DESKTOP=%s\n' $XDG_CURRENT_DESKTOP
```

Verify fzf integration:

```fish
type -a fzf
set --show FZF_DEFAULT_OPTS_FILE
```

An unset `FZF_DEFAULT_OPTS_FILE` is acceptable if configuration is managed
another way. It should not reference a removed or obsolete file.

## 17. Verify rclone

Run:

```fish
rclone-sync-status
```

On the designated sync laptop, expected output includes:

```text
Rclone role: PRIMARY WRITER
Last result: SUCCESS
```

Check the timer:

```fish
systemctl --user list-timers \
    rclone-hourly-sync.timer \
    --all \
    --no-pager
```

Check remotes:

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

See [rclone Setup](rclone.md) for dry runs, activation, deletion protection, and
laptop handoff.

## 18. Verify sensitive-file permissions

```fish
stat -c '%A %a %U:%G %n' \
    ~/.config/age/key.txt \
    ~/.config/rclone/rclone.conf \
    ~/.ssh/config \
    ~/.ssh/id_ed25519
```

Expected mode:

```text
600
```

Check the SSH directory:

```fish
stat -c '%A %a %U:%G %n' ~/.ssh
```

Expected mode:

```text
700
```

## 19. Review recent errors

User journal warnings and errors from the current boot:

```fish
journalctl --user \
    --boot \
    --priority=warning \
    --no-pager
```

System warnings and errors:

```fish
journalctl \
    --boot \
    --priority=warning \
    --no-pager
```

Some warnings may be harmless. Focus on repeated failures, missing files,
crashes, and services that affect the current setup.

## 20. Final checklist

A fully healthy system should satisfy all of the following:

- The expected BlueBuild image is booted.
- Core commands are present.
- Chezmoi reports no differences.
- The dotfiles Git repository is clean.
- The age recipient matches.
- SSH-agent socket is active.
- GitHub SSH authentication succeeds.
- No unexpected user units are failed.
- Niri is active.
- Niri configuration validates.
- Noctalia is running through Niri autostart.
- Theme switching updates GTK and the appearance portal.
- GNOME and GTK portals are active.
- PipeWire and WirePlumber are running.
- swayidle is active.
- Flatpaks are installed once at the system level.
- Intended Flatpak overrides remain active.
- Neovim starts without errors.
- Fish starts without warnings.
- rclone is successful or intentionally disabled.
- Sensitive files have correct permissions.
