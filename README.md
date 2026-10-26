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

Enable the systemd OpenSSH agent:

```bash
systemctl --user enable --now ssh-agent.socket
```

Configure its socket for future logins:

```bash
mkdir -p ~/.config/environment.d
printf 'SSH_AUTH_SOCK=/run/user/%s/ssh-agent.socket\n' "$(id -u)" \
  > ~/.config/environment.d/10-ssh-agent.conf
```

Configure SSH to automatically cache the key after its first use. Add the following to `~/.ssh/config`:

```sshconfig
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519
    IdentitiesOnly yes
    AddKeysToAgent yes
```

Secure the configuration:

```bash
chmod 600 ~/.ssh/config
```

Log out and back in to activate the environment configuration.

On the first GitHub connection, enter your SSH key passphrase. SSH will automatically add the unlocked key to the agent for subsequent connections during that login session.

Verify with:

```bash
ssh -T git@github.com
ssh-add -l
```

The private key remains passphrase-protected. After a full logout or reboot, the key may need to be unlocked again.

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
