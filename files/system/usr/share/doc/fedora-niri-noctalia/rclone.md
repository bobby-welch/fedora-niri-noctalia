# rclone Setup

This setup performs a one-way hourly sync from one designated laptop to pCloud.

## Synced directories

| Local directory | Remote destination |
| --------------- | ------------------ |
| `~/Documents`   | `pcloud:Documents` |
| `~/Pictures`    | `pcloud:Pictures`  |
| `~/eBooks`      | `eBooks:`          |

The `eBooks:` remote encrypts file contents while intentionally leaving
filenames, directory names, and directory structure visible.

This is synchronization, not a complete backup. Destination-only files can be
deleted so the remote matches the local source. Recovery also depends on the
retention available from pCloud Trash and file history.

The sync does not use `--backup-dir` or separate archive directories.

## Design

The setup uses:

- one sequential sync script;
- one systemd user service;
- one hourly systemd user timer;
- one failure-notification service;
- one status command;
- one machine-local primary-writer marker.

Only one laptop may be the active writer.

## Managed files

Chezmoi manages:

```text
~/.local/bin/rclone-hourly-sync
~/.local/bin/rclone-sync-status
~/.config/systemd/user/rclone-hourly-sync.service
~/.config/systemd/user/rclone-hourly-sync.timer
~/.config/systemd/user/rclone-sync-notify.service
~/.config/rclone/rclone.conf
```

The rclone configuration is encrypted in the chezmoi repository with age.

Chezmoi does not manage:

```text
~/.config/rclone-sync/enabled
~/.local/state/rclone-sync/status
~/.config/age/key.txt
```

The enable marker is machine-specific. The status file is runtime state. The age
identity must be restored securely from 1Password.

## Normal status check

Run:

```fish
rclone-sync-status
```

A healthy primary laptop should report:

```text
Rclone role: PRIMARY WRITER
Last result: SUCCESS
```

A successfully completed oneshot service normally reports:

```text
ActiveState=inactive
SubState=dead
Result=success
ExecMainStatus=0
```

`inactive (dead)` is normal after the sync finishes.

## View logs

Show the latest sync logs:

```fish
journalctl --user \
    -u rclone-hourly-sync.service \
    -n 100 \
    --no-pager
```

Follow an active run:

```fish
journalctl --user \
    -u rclone-hourly-sync.service \
    -f
```

## Run a manual sync

On the designated primary laptop:

```fish
systemctl --user start rclone-hourly-sync.service
```

Then check:

```fish
rclone-sync-status
```

## Check the timer

```fish
systemctl --user list-timers \
    rclone-hourly-sync.timer \
    --all \
    --no-pager
```

## Enable automatic syncing

Only do this on the designated primary laptop.

Create the primary-writer marker:

```fish
mkdir -p ~/.config/rclone-sync

printf '%s\n' \
    "Primary rclone writer: $(hostname)" \
    > ~/.config/rclone-sync/enabled

chmod 600 ~/.config/rclone-sync/enabled
```

Enable the hourly timer:

```fish
systemctl --user enable --now \
    rclone-hourly-sync.timer
```

Verify:

```fish
rclone-sync-status
```

## Disable automatic syncing

Disable and stop the timer:

```fish
systemctl --user disable --now \
    rclone-hourly-sync.timer
```

Stop a sync that is already running:

```fish
systemctl --user stop \
    rclone-hourly-sync.service
```

Remove the primary-writer marker:

```fish
rm -f ~/.config/rclone-sync/enabled
```

Verify:

```fish
rclone-sync-status
```

It should report:

```text
Rclone role: DISABLED
```

## Fresh-install restoration

### 1. Confirm required software

The BlueBuild image should provide:

```fish
command -v rclone
command -v chezmoi
command -v age
```

### 2. Restore the age identity

Restore the `Chezmoi age identity key` document from 1Password to:

```text
~/.config/age/key.txt
```

Create the directory and secure the file:

```fish
mkdir -p ~/.config/age

chmod 600 ~/.config/age/key.txt
```

Verify the public recipient:

```fish
age-keygen -y ~/.config/age/key.txt
```

Expected recipient:

```text
age1gdv6nj37ekn2v3r7pw907ujvzhujgeghnsqw8umeyk0tm0v38y3sg542zj
```

Do not continue if the recipient differs.

### 3. Initialize chezmoi

Initialize and apply the dotfiles repository:

```fish
chezmoi init --apply git@github.com:bobby-welch/dotfiles.git
```

The repository’s `.chezmoi.toml.tmpl` configures age encryption and uses:

```text
~/.config/age/key.txt
```

Chezmoi should decrypt and restore:

```text
~/.config/rclone/rclone.conf
```

### 4. Verify the restored rclone configuration

Check its permissions:

```fish
stat -c '%A %a %U:%G %n' \
    ~/.config/rclone/rclone.conf
```

Expected mode:

```text
600
```

List configured remotes:

```fish
rclone listremotes
```

Expected:

```text
pcloud:
eBooks:
```

Test pCloud access:

```fish
rclone about pcloud:
```

Test the encrypted eBooks remote:

```fish
rclone lsf eBooks: \
    --max-depth 1 \
    | head -n 20
```

The eBooks listing should show normal decrypted names.

### 5. Restore synchronized directories

Create the local directories:

```fish
mkdir -p ~/Documents ~/Pictures ~/eBooks
```

On a fresh installation, restore the remote contents without deleting anything
from the local destination:

```fish
rclone copy pcloud:Documents ~/Documents --progress
rclone copy pcloud:Pictures ~/Pictures --progress
rclone copy eBooks: ~/eBooks --progress
```

The `eBooks:` command decrypts names and file contents while restoring them.

Inspect the restored data:

```fish
for dir in ~/Documents ~/Pictures ~/eBooks
    printf '\n=== %s ===\n' $dir
    find $dir -mindepth 1 -maxdepth 2 | head -n 20
end
```

Do not enable synchronization until all three directories contain the intended
authoritative local data.

### 6. Reload systemd

```fish
systemctl --user daemon-reload
```

Verify the units:

```fish
systemctl --user list-unit-files --no-pager \
    | rg 'rclone-hourly-sync|rclone-sync-notify'
```

### 7. Confirm syncing is initially disabled

Before creating the primary marker:

```fish
rclone-sync-status
```

It should report:

```text
Rclone role: DISABLED
```

### 8. Perform dry runs

Documents:

```fish
rclone sync \
    ~/Documents \
    pcloud:Documents \
    --dry-run \
    --combined=- \
    --retries=1 \
    --log-level=ERROR
```

Pictures:

```fish
rclone sync \
    ~/Pictures \
    pcloud:Pictures \
    --dry-run \
    --combined=- \
    --retries=1 \
    --log-level=ERROR
```

eBooks:

```fish
rclone sync \
    ~/eBooks \
    eBooks: \
    --dry-run \
    --combined=- \
    --retries=1 \
    --log-level=ERROR
```

Review all proposed uploads, updates, and deletions carefully. In particular,
confirm that destination-only files marked for deletion are genuinely obsolete.

### 9. Designate the primary laptop

Only after the dry runs look correct:

```fish
mkdir -p ~/.config/rclone-sync

printf '%s\n' \
    "Primary rclone writer: $(hostname)" \
    > ~/.config/rclone-sync/enabled

chmod 600 ~/.config/rclone-sync/enabled
```

### 10. Run one manual sync

```fish
systemctl --user start \
    rclone-hourly-sync.service
```

Verify:

```fish
rclone-sync-status
```

Proceed only if it reports:

```text
Last result: SUCCESS
```

### 11. Enable the hourly timer

```fish
systemctl --user enable --now \
    rclone-hourly-sync.timer
```

Verify the schedule:

```fish
systemctl --user list-timers \
    rclone-hourly-sync.timer \
    --all \
    --no-pager
```

## Laptop handoff

Never leave two laptops authorized as writers.

### On the old primary laptop

Run a final sync:

```fish
systemctl --user start \
    rclone-hourly-sync.service
```

Confirm success:

```fish
rclone-sync-status
```

Disable the timer:

```fish
systemctl --user disable --now \
    rclone-hourly-sync.timer
```

Remove the marker:

```fish
rm -f ~/.config/rclone-sync/enabled
```

### On the new primary laptop

Ensure its local Documents, Pictures, and eBooks directories are fully current.

Run dry runs and inspect all proposed changes.

Create the marker:

```fish
mkdir -p ~/.config/rclone-sync

printf '%s\n' \
    "Primary rclone writer: $(hostname)" \
    > ~/.config/rclone-sync/enabled

chmod 600 ~/.config/rclone-sync/enabled
```

Run one manual sync:

```fish
systemctl --user start \
    rclone-hourly-sync.service
```

Confirm success:

```fish
rclone-sync-status
```

Enable the timer:

```fish
systemctl --user enable --now \
    rclone-hourly-sync.timer
```

## Failure behavior

A failed sync:

- exits with a nonzero status;
- appears in the user journal;
- updates the status file;
- triggers a desktop notification;
- remains visible through `rclone-sync-status`.

Check failed user services:

```fish
systemctl --user --failed
```

Reset a resolved failure:

```fish
systemctl --user reset-failed \
    rclone-hourly-sync.service
```

## Deletion protection

The regular sync uses deletion-count and deletion-size limits.

Current limits:

| Directory | Maximum deleted files | Maximum deleted size |
| --------- | --------------------: | -------------------: |
| Documents |                   100 |                5 GiB |
| Pictures  |                   500 |               25 GiB |
| eBooks    |                   100 |                2 GiB |

If a legitimate cleanup exceeds a limit:

1. stop;
2. run a dry run;
3. inspect the proposed deletions;
4. run a one-time manual command with a temporary higher limit;
5. leave the regular script’s lower limit unchanged.

## Security notes

The following files contain sensitive recovery material:

```text
~/.config/rclone/rclone.conf
~/.config/age/key.txt
```

Required permissions:

```text
600
```

The age private key is backed up in 1Password as:

```text
Chezmoi age identity key
```

The private age key must never be committed to Git or pasted into logs, chat, or
documentation.

The encrypted chezmoi source file is:

```text
private_dot_config/rclone/encrypted_private_rclone.conf.age
```

## Useful commands

Check health:

```fish
rclone-sync-status
```

Run now:

```fish
systemctl --user start \
    rclone-hourly-sync.service
```

View logs:

```fish
journalctl --user \
    -u rclone-hourly-sync.service \
    -n 100 \
    --no-pager
```

Check timer:

```fish
systemctl --user list-timers \
    rclone-hourly-sync.timer \
    --all \
    --no-pager
```

Disable this laptop:

```fish
systemctl --user disable --now \
    rclone-hourly-sync.timer

rm -f ~/.config/rclone-sync/enabled
```
