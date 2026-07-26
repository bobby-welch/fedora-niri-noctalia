# Workflows

This guide contains the normal operating and maintenance workflows for the
Fedora Niri Noctalia workstation.

## Daily use

No routine maintenance command is required. Image updates are staged
automatically, and system and user Flatpaks update automatically.

Reboot when `ujust system-audit` reports that a newer deployment is staged.

## Weekly check

```fish
ujust system-audit
```

Warnings are informational. Resolve every failure before making unrelated
system changes.

## Apply updates immediately

Run the inherited update workflow when an immediate refresh is desired:

```fish
ujust update
systemctl reboot
```

After rebooting:

```fish
ujust system-audit
```

This updates the image, Flatpaks, and Distrobox containers using the mechanisms
provided by the base image.

## Update dotfiles

### Edit a managed destination

```fish
nvim ~/.config/example/config
chezmoi add ~/.config/example/config
chezmoi diff
```

Review the source repository, identify the generated source path, then commit
and push:

```fish
chezmoi source-path ~/.config/example/config

git -C ~/.local/share/chezmoi diff
git -C ~/.local/share/chezmoi status

git -C ~/.local/share/chezmoi add <source-path>
git -C ~/.local/share/chezmoi commit -m "Describe the change"
git -C ~/.local/share/chezmoi push
```

Finish with:

```fish
chezmoi-audit
```

### Edit the chezmoi source directly

```fish
chezmoi edit ~/.config/example/config
chezmoi apply ~/.config/example/config
chezmoi-audit
```

### Pull changes from GitHub

Use the review-first workflow:

```fish
git -C ~/.local/share/chezmoi pull --ff-only
chezmoi diff
chezmoi apply
chezmoi-audit
```

## Update the BlueBuild image

Make host package and system-file changes in the BlueBuild repository rather
than installing them manually on the running workstation.

```fish
cd ~/.local/src/fedora-niri-noctalia
nvim recipes/recipe.yml

git diff --check
git diff
git status
```

Commit and push:

```fish
git add <paths>
git commit -m "Describe the image change"
git push
```

After the build succeeds and the update is staged, reboot and verify:

```fish
systemctl reboot
ujust system-audit
```

## Update workstation tools

```fish
ujust update-markdownlint
ujust update-harper
ujust update-cloudflare-speed-cli
```

Use `ujust setup-node-tools` to create or restore the declarative Node tools
Distrobox. It installs the configured Markdownlint version during setup;
`ujust update-markdownlint` is for deliberate later updates.

## rclone

Check status:

```fish
rclone-sync-status
```

Run a manual sync on the designated writer:

```fish
systemctl --user start rclone-hourly-sync.service
rclone-sync-status
```

Review recent logs:

```fish
journalctl --user \
    -u rclone-hourly-sync.service \
    -n 100 \
    --no-pager
```

Never enable a second writer. Follow [rclone Setup](rclone.md) for restoration,
handoff, dry runs, or failure recovery.

## Firmware

Check and apply firmware updates when available:

```fish
fwupdmgr refresh
fwupdmgr get-updates
sudo fwupdmgr update
```

Reboot when requested, then run:

```fish
ujust system-audit
```

## Cleanup

Routine cleanup is generally unnecessary. Inspect before deleting anything:

```fish
podman system df
flatpak uninstall --unused
```

Do not manually remove rpm-ostree deployments as routine maintenance.

## Roll back the system

Use rollback only when the newly booted deployment has a system-level problem:

```fish
sudo bootc status
sudo bootc rollback
systemctl reboot
```

After rebooting:

```fish
ujust system-audit
```

Rollback does not replace restoration of user data, dotfiles, or rclone data.
