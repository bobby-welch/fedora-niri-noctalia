# Fedora Niri Noctalia

[![BlueBuild build status](https://github.com/bobby-welch/fedora-niri-noctalia/actions/workflows/build.yml/badge.svg)](https://github.com/bobby-welch/fedora-niri-noctalia/actions/workflows/build.yml)

A personal Fedora Atomic desktop image built around Niri and Noctalia.

## Start here

For a normal rebuild, use the concise guide:

- [Quick installation guide][quick]

Use the detailed guides when a quick-install step fails or needs explanation:

- [Detailed installation and recovery guide][install]
- [SSH and GitHub setup][ssh]
- [Chezmoi setup and workflow][chezmoi]
- [rclone setup and recovery][rclone]
- [System health checks][checks]

After installing and booting the image:

```fish
nvim /usr/share/doc/fedora-niri-noctalia/quick-install.md
```

## Create the installation ISO

Create an installer from the published image:

```fish
mkdir -p ~/Downloads/ISO

sudo bluebuild generate-iso \
    --output-dir ~/Downloads/ISO \
    --iso-name fedora-niri-noctalia.iso \
    --variant kinoite \
    image ghcr.io/bobby-welch/fedora-niri-noctalia:latest
```

The Kinoite option selects the installer profile. The installed target remains
the Fedora Niri Noctalia image.

Verify the generated ISO:

```fish
cd ~/Downloads/ISO

sha256sum --check \
    fedora-niri-noctalia.iso-CHECKSUM
```

Expected result:

```text
fedora-niri-noctalia.iso: OK
```

## Write the ISO to USB

> **Warning**
>
> This procedure erases the selected USB drive. Verify the device path
> carefully.

Compare block devices before and after inserting the USB drive:

```fish
lsblk -o NAME,PATH,SIZE,MODEL,TRAN,RM,FSTYPE,MOUNTPOINTS
```

Use the whole device, such as `/dev/sdX`, not a partition such as `/dev/sdX1`.

Unmount any mounted USB partitions, then write the ISO:

```fish
sudo umount /dev/sdX1

sudo dd \
    if=~/Downloads/ISO/fedora-niri-noctalia.iso \
    of=/dev/sdX \
    bs=4M \
    status=progress \
    conv=fsync
```

Do not disconnect the drive until `dd` exits successfully.

## Install

1. Boot from the USB drive.
2. Complete the Fedora installer.
3. Remove the USB drive.
4. Boot the installed system.
5. Verify the image:

```fish
sudo bootc status
```

The booted image should be:

```text
ghcr.io/bobby-welch/fedora-niri-noctalia:latest
```

Continue with:

```fish
nvim /usr/share/doc/fedora-niri-noctalia/quick-install.md
```

## Fallback installation path

If the generated installer does not work on the target hardware, install a
supported Fedora Atomic desktop first and then switch it to this image using
BlueBuild's current rebase instructions.

The direct custom ISO remains the preferred path.

## Image maintenance

The image recipe is:

```text
recipes/recipe.yml
```

GitHub Actions builds the image daily, when relevant repository content changes,
or when manually triggered.

Changes only to the root `README.md` do not trigger a build. Files included in
the image, including documentation under `files/system/`, do trigger a build.

### Update the installed system

```fish
sudo bootc upgrade --check
sudo bootc upgrade
sudo bootc status
systemctl reboot
```

To update and reboot in one operation:

```fish
sudo bootc upgrade --apply
```

### Roll back

```fish
sudo bootc status
sudo bootc rollback
systemctl reboot
```

To roll back immediately:

```fish
sudo bootc rollback --apply
```

A rollback discards an unapplied staged update. Files under `/etc` revert to the
state associated with the rollback deployment.

## Signature verification

From the repository root:

```fish
cosign verify \
    --key cosign.pub \
    ghcr.io/bobby-welch/fedora-niri-noctalia
```

[quick]: files/system/usr/share/doc/fedora-niri-noctalia/quick-install.md
[install]: files/system/usr/share/doc/fedora-niri-noctalia/install.md
[ssh]: files/system/usr/share/doc/fedora-niri-noctalia/ssh-github.md
[chezmoi]: files/system/usr/share/doc/fedora-niri-noctalia/chezmoi.md
[rclone]: files/system/usr/share/doc/fedora-niri-noctalia/rclone.md
[checks]: files/system/usr/share/doc/fedora-niri-noctalia/system-checks.md
