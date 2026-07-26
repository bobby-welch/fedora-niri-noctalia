# Fedora Niri Noctalia

[![BlueBuild build status](https://github.com/bobby-welch/fedora-niri-noctalia/actions/workflows/build.yml/badge.svg)](https://github.com/bobby-welch/fedora-niri-noctalia/actions/workflows/build.yml)

A personal Fedora Atomic desktop image built with BlueBuild around Niri and
Noctalia.

## Documentation

- [Quick installation][quick] — rebuild the workstation from the installer ISO
- [Workflows][workflows] — normal updates, maintenance, dotfiles, and rollback
- [SSH and GitHub][ssh] — device key setup and troubleshooting
- [Chezmoi][chezmoi] — restore and maintain the dotfiles repository
- [rclone][rclone] — restore, sync, hand off, and recover synchronized data
- [System checks][checks] — targeted diagnostics after `ujust system-audit`

The installed copies are available at:

```text
/usr/share/doc/fedora-niri-noctalia/
```

Start a fresh rebuild with:

```fish
nvim /usr/share/doc/fedora-niri-noctalia/quick-install.md
```

## Create the installation ISO

```fish
mkdir -p ~/Downloads/ISO

sudo bluebuild generate-iso \
    --output-dir ~/Downloads/ISO \
    --iso-name fedora-niri-noctalia.iso \
    --variant kinoite \
    image ghcr.io/bobby-welch/fedora-niri-noctalia:latest
```

The Kinoite option selects the installer profile; the installed target remains
this custom image.

Verify the ISO:

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
> This erases the selected USB drive. Verify the device path carefully and use
> the whole device, such as `/dev/sdX`, not a partition such as `/dev/sdX1`.

Identify the USB drive:

```fish
lsblk -o NAME,PATH,SIZE,MODEL,TRAN,RM,FSTYPE,MOUNTPOINTS
```

Unmount its mounted partitions and write the image:

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
5. Follow the [quick installation guide][quick].

If the custom installer does not work on the target hardware, install a
supported Fedora Atomic desktop and follow BlueBuild's current rebase
instructions.

## Image development

The image recipe is:

```text
recipes/recipe.yml
```

Make host package and system-file changes in the repository rather than with
`dnf install` on the running workstation. GitHub Actions builds the image when
relevant repository content changes, on its schedule, or when manually
triggered.

Normal operating, update, rollback, and verification procedures are documented
in [Workflows][workflows].

## Signature verification

From the repository root:

```fish
cosign verify \
    --key cosign.pub \
    ghcr.io/bobby-welch/fedora-niri-noctalia
```

[quick]: files/system/usr/share/doc/fedora-niri-noctalia/quick-install.md
[workflows]: files/system/usr/share/doc/fedora-niri-noctalia/workflows.md
[ssh]: files/system/usr/share/doc/fedora-niri-noctalia/ssh-github.md
[chezmoi]: files/system/usr/share/doc/fedora-niri-noctalia/chezmoi.md
[rclone]: files/system/usr/share/doc/fedora-niri-noctalia/rclone.md
[checks]: files/system/usr/share/doc/fedora-niri-noctalia/system-checks.md
