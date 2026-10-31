# Fedora Niri Noctalia

[![Build](https://github.com/bobby-welch/fedora-niri-noctalia/actions/workflows/build.yml/badge.svg)](https://github.com/bobby-welch/fedora-niri-noctalia/actions/workflows/build.yml)

A personal Fedora 44 Atomic desktop built with [BlueBuild](https://blue-build.org/), [Niri](https://github.com/YaLTeR/niri), and [Noctalia](https://noctalia.dev/).

## Installation

### Generate the ISO

On Fedora, install the BlueBuild CLI using Podman:

```bash
podman run --pull always --rm \
  ghcr.io/blue-build/cli:latest-installer | bash
```

For other operating systems, see the [official BlueBuild CLI installation instructions](https://github.com/blue-build/cli#installation).

Verify the installation:

```bash
bluebuild --version
```

Generate an ISO from the published image:

```bash
sudo bluebuild generate-iso \
  --variant server \
  --iso-name fedora-niri-noctalia.iso \
  image ghcr.io/bobby-welch/fedora-niri-noctalia:latest
```

**Installer note:** The default `kinoite` installer variant previously hid the user-creation screen. The `server` variant exposed it, but a full installation using that variant has not yet been tested. This is the reason for the `--variant server` option.

### Write to USB

Identify the USB device:

```bash
lsblk -o NAME,SIZE,MODEL,TRAN,MOUNTPOINTS
```

Unmount any mounted partitions on the selected device. Then write the ISO to the **whole device**, replacing `/dev/sdX` with its actual path:

```bash
sudo umount /dev/sdX1  # Only if this partition is mounted
sudo dd if=fedora-niri-noctalia.iso of=/dev/sdX bs=4M status=progress conv=fsync
```

**Warning:** Verify the USB device before writing. All existing data on the selected device will be erased.

### Install

Boot from the USB drive, follow the installer, create an administrator account, and reboot.

## Post-install configuration

### Hostname

Choose a hostname for the machine:

```bash
sudo hostnamectl set-hostname my-laptop
```

Replace `my-laptop` with your preferred name.

### GitHub and SSH

Generate a passphrase-protected SSH key on the new machine:

```bash
ssh-keygen -t ed25519 -a 100 -C "My Laptop"
```

Authenticate with GitHub:

```bash
gh auth login
```

Choose **GitHub.com**, **SSH**, and browser authentication. When prompted, allow GitHub CLI to upload the **public** key to your account. Keep the private key on the machine; never upload or share it.

Verify authentication:

```bash
gh auth status
ssh -T git@github.com
```

Configure your Git name and email separately, if needed.

### SSH agent

Enable the systemd user SSH agent:

```bash
systemctl --user enable --now ssh-agent.socket
```

Configure the socket for future logins:

```bash
mkdir -p ~/.config/environment.d
printf 'SSH_AUTH_SOCK=/run/user/%s/ssh-agent.socket\n' "$(id -u)" \
  > ~/.config/environment.d/10-ssh-agent.conf
```

Add the following to `~/.ssh/config` (create the file if necessary):

```sshconfig
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519
    IdentitiesOnly yes
    AddKeysToAgent yes
```

Secure the file:

```bash
chmod 600 ~/.ssh/config
```

Log out and back in to load the environment setting. After unlocking the key once, the SSH agent can reuse it during the session. Check with:

```bash
ssh-add -l
ssh -T git@github.com
```

### Display scaling

Niri display outputs and scale factors vary by machine. Inspect the available outputs:

```bash
niri msg outputs
```

For example, to set the internal display to a scale of `1.6` for the current session:

```bash
niri msg output eDP-1 scale 1.6
```

For a persistent setting, adjust the corresponding `output` block in `~/.config/niri/config.kdl`. Check the output name and choose the scale appropriate for the laptop or monitor.

## Updates and rollback

The Fedora image is rebuilt daily through GitHub Actions. On the installed machine, bootc updates are managed manually; the automatic `bootc-fetch-apply-updates.timer` is disabled.

Download and stage the latest image, then inspect deployment status:

```bash
sudo bootc upgrade
sudo bootc status
```

Reboot when ready to activate the staged image:

```bash
systemctl reboot
```

To roll back to the previous deployment:

```bash
sudo bootc rollback
systemctl reboot
```

## Verify the image signature

The published image is cryptographically signed. If [Cosign](https://docs.sigstore.dev/cosign/system_config/installation/) is installed, you can verify its signature from a checkout of this repository using the included `cosign.pub`:

```bash
cosign verify --key cosign.pub \
  ghcr.io/bobby-welch/fedora-niri-noctalia:latest
```
