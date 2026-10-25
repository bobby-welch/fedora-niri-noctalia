# Fedora Noctalia

[![Build](https://github.com/bobby-welch/fedora-noctalia/actions/workflows/build.yml/badge.svg)](https://github.com/bobby-welch/fedora-noctalia/actions/workflows/build.yml)

A personal Fedora 44 Atomic desktop built with [BlueBuild](https://blue-build.org/), [Niri](https://github.com/YaLTeR/niri), and [Noctalia](https://noctalia.dev/).

> Experimental — physical hardware installation is not yet verified.

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
