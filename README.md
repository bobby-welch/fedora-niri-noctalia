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

After the image is installed, open the local guide with:

```bash
nvim /usr/share/doc/fedora-niri-noctalia/install.md
```

## Install on an existing Fedora Atomic system

First switch to the unsigned image so the image-provided signing policy and
public key are installed:

```bash
rpm-ostree rebase \
    ostree-unverified-registry:ghcr.io/bobby-welch/fedora-niri-noctalia:latest
```

Reboot:

```bash
systemctl reboot
```

Then switch to the signed image:

```bash
rpm-ostree rebase \
    ostree-image-signed:docker://ghcr.io/bobby-welch/fedora-niri-noctalia:latest
```

Reboot again:

```bash
systemctl reboot
```

Verify the active deployment:

```bash
rpm-ostree status
```

The active deployment should reference:

```text
ghcr.io/bobby-welch/fedora-niri-noctalia:latest
```

and use the signed transport:

```text
ostree-image-signed:docker://
```

## Image source

The main recipe is:

```text
recipes/recipe.yml
```

GitHub Actions builds the image:

- daily;
- when relevant repository changes are pushed;
- when manually triggered.

The Fedora major version remains pinned by `image-version` in the recipe.

## Rollback

Fedora Atomic retains the previous deployment.

Select the previous deployment from the boot menu, or run:

```bash
rpm-ostree rollback
systemctl reboot
```

## Signature verification

The image is signed with Sigstore cosign.

```bash
cosign verify \
    --key cosign.pub \
    ghcr.io/bobby-welch/fedora-niri-noctalia
```
