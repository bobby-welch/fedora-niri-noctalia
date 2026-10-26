# Fedora Noctalia

[![Build](https://github.com/bobby-welch/fedora-noctalia/actions/workflows/build.yml/badge.svg)](https://github.com/bobby-welch/fedora-noctalia/actions/workflows/build.yml)

A personal Fedora 44 Atomic desktop built with [BlueBuild](https://blue-build.org/), [Niri](https://github.com/YaLTeR/niri), and [Noctalia](https://noctalia.dev/).

> Tested on a Dell XPS 13. Installer account creation remains under investigation.

## Installation

### Generate the ISO

Requires the [BlueBuild CLI](https://blue-build.org/how-to/generate-iso/).

```bash
sudo bluebuild generate-iso \
  --iso-name fedora-noctalia.iso \
  image ghcr.io/bobby-welch/fedora-noctalia:latest
```

### Write to USB

Identify the USB device:

```bash
lsblk -o NAME,SIZE,MODEL,TRAN,MOUNTPOINTS
```

Unmount any mounted partitions on that device, then write the ISO:

```bash
sudo umount /dev/sdX1
sudo dd if=fedora-noctalia.iso of=/dev/sdX bs=4M status=progress conv=fsync
```

**Warning:** Replace `/dev/sdX` with the correct whole-disk device. All data on it will be overwritten. Unmount every mounted partition before writing.

### Install

Boot from USB, follow the installer, and reboot.

**Known issue:** The current ISO may not prompt for account creation, leaving the installed system without a usable login. A different installer variant is being evaluated.

## Post-install configuration

### Hostname

Set a hostname appropriate for your device:

```bash
sudo hostnamectl set-hostname my-laptop
```

### GitHub and SSH

Generate a passphrase-protected SSH key:

```bash
ssh-keygen -t ed25519 -a 100 -C "My Laptop"
```

Authenticate with GitHub:

```bash
gh auth login
```

Choose GitHub.com, SSH, and browser authentication. Register the public key when prompted.

Verify authentication:

```bash
gh auth status
ssh -T git@github.com
```

Configure your Git name and email separately.

### SSH agent

Enable the systemd SSH agent:

```bash
systemctl --user enable --now ssh-agent.socket
```

Create `~/.config/environment.d/10-ssh-agent.conf`:

```ini
SSH_AUTH_SOCK=%t/ssh-agent.socket
```

Activate the socket in your current terminal and load your key:

```bash
export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/ssh-agent.socket"
ssh-add ~/.ssh/id_ed25519
```

Log out and back in to make the environment configuration persistent. The private key remains passphrase-protected.

### Display scaling

Niri scaling is device-specific. On a Dell XPS 13 with a 2560 × 1600 display, the following was tested:

```bash
niri msg output eDP-1 scale 1.6
```

For persistent scaling, configure the appropriate output in `~/.config/niri/config.kdl`. Do not apply this setting globally.

## Updates

OS updates are configured to be downloaded and staged automatically for the next reboot.

To update manually:

```bash
sudo bootc upgrade
```

Reboot to activate the update.

## Rollback

Restore the previous deployment:

```bash
sudo bootc rollback
systemctl reboot
```
