# Fedora Niri Noctalia

[![BlueBuild build status](https://github.com/bobby-welch/fedora-niri-noctalia/actions/workflows/build.yml/badge.svg)](https://github.com/bobby-welch/fedora-niri-noctalia/actions/workflows/build.yml)

A personal Fedora Atomic desktop image built around Niri and Noctalia.

## Documentation

The complete rebuild documentation is included in this repository and installed
with the image.

- [Complete installation guide](files/system/usr/share/doc/fedora-niri-noctalia/install.md)
- [SSH and GitHub setup](files/system/usr/share/doc/fedora-niri-noctalia/ssh-github.md)
- [Chezmoi setup and workflow](files/system/usr/share/doc/fedora-niri-noctalia/chezmoi.md)
- [rclone setup](files/system/usr/share/doc/fedora-niri-noctalia/rclone.md)
- [System health checks](files/system/usr/share/doc/fedora-niri-noctalia/system-checks.md)

After installing and booting the image, open the local installation guide:

```fish
nvim /usr/share/doc/fedora-niri-noctalia/install.md
```

## Create the installation ISO

Create a directory for generated installer images:

```fish
mkdir -p ~/Downloads/ISO
```

Generate an installer ISO from the published BlueBuild image:

```fish
sudo bluebuild generate-iso \
    --output-dir ~/Downloads/ISO \
    --iso-name fedora-niri-noctalia.iso \
    --variant kinoite \
    image ghcr.io/bobby-welch/fedora-niri-noctalia:latest
```

This command installs the Fedora Niri Noctalia image. The Kinoite variant
selects the installer profile and does not replace the target image with Fedora
Kinoite.

The generated files are:

```text
~/Downloads/ISO/fedora-niri-noctalia.iso
~/Downloads/ISO/fedora-niri-noctalia.iso-CHECKSUM
```

Verify the ISO:

```fish
cd ~/Downloads/ISO
sha256sum --check fedora-niri-noctalia.iso-CHECKSUM
```

Expected result:

```text
fedora-niri-noctalia.iso: OK
```

## Write the ISO to a USB drive

> **Warning**
>
> The following procedure erases the entire selected USB drive. Verify the
> device path carefully before running `dd`.

Before inserting the USB drive, inspect the current block devices:

```fish
lsblk -o NAME,PATH,SIZE,MODEL,TRAN,RM,FSTYPE,MOUNTPOINTS
```

Insert the USB drive and run the command again:

```fish
lsblk -o NAME,PATH,SIZE,MODEL,TRAN,RM,FSTYPE,MOUNTPOINTS
```

Identify the new device by its size, model, transport, and removable status.

Use the whole device, such as:

```text
/dev/sdX
```

Do not use a partition such as:

```text
/dev/sdX1
```

Unmount any mounted partitions on the USB drive. Replace `/dev/sdX1` with each
mounted partition shown by `lsblk`:

```fish
sudo umount /dev/sdX1
```

Write the ISO to the whole USB device. Replace `/dev/sdX` with the verified
device path:

```fish
sudo dd \
    if=~/Downloads/ISO/fedora-niri-noctalia.iso \
    of=/dev/sdX \
    bs=4M \
    status=progress \
    conv=fsync
```

Do not disconnect the USB drive until `dd` exits successfully.

## Install the image

1. Reboot the computer with the USB drive inserted.
2. Open the computer’s one-time boot menu.
3. Select the USB drive.
4. Start the Fedora installer.
5. Configure the target disk, user account, locale, and time zone.
6. Complete the installation.
7. Remove the USB drive when prompted.
8. Boot the installed system.

Verify that the expected image is active:

```fish
sudo bootc status
```

The booted image should be:

```text
ghcr.io/bobby-welch/fedora-niri-noctalia:latest
```

Then continue with:

```fish
nvim /usr/share/doc/fedora-niri-noctalia/install.md
```

## Fallback installation path

If the generated installer cannot boot or install successfully on the target
hardware, install a supported Fedora Atomic desktop image first and then switch
that installation to the Fedora Niri Noctalia image.

The direct ISO installation is the preferred workflow. The Fedora Atomic
bootstrap method is retained only as a recovery path. Follow BlueBuild's current
rebase documentation rather than relying on commands copied from this README.

## Image source

The main recipe is:

```text
recipes/recipe.yml
```

GitHub Actions builds the image:

- daily at 06:00 UTC;
- when relevant repository changes are pushed;
- when manually triggered.

Changes only to the root `README.md` do not trigger an image build. Changes to
files included in the image, including the bundled documentation under
`files/system/`, do trigger a build.

The Fedora major version remains pinned by `image-version` in the recipe.

## Update the installed system

Check whether an update is available:

```fish
sudo bootc upgrade --check
```

Download and queue an available update:

```fish
sudo bootc upgrade
```

Inspect the current and staged deployments:

```fish
sudo bootc status
```

Reboot into the staged deployment:

```fish
systemctl reboot
```

To download, queue, and immediately reboot into an available update:

```fish
sudo bootc upgrade --apply
```

## Rollback

The previous deployment is retained as the rollback image.

Inspect the available deployments:

```fish
sudo bootc status
```

Queue the rollback for the next boot:

```fish
sudo bootc rollback
systemctl reboot
```

To apply the rollback immediately:

```fish
sudo bootc rollback --apply
```

A rollback discards an unapplied staged update. Files under `/etc` revert to the
state associated with the rollback deployment.

## Signature verification

The container image is signed with Sigstore cosign.

From the repository root, verify the image with:

```fish
cosign verify \
    --key cosign.pub \
    ghcr.io/bobby-welch/fedora-niri-noctalia
```
