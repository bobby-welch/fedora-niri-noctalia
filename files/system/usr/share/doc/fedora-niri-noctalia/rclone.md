# rclone Setup

This system performs a one-way hourly sync from one designated laptop to
pCloud.

| Local directory | Remote destination |
| ---------------- | ------------------ |
| `~/Documents`    | `pcloud:Documents` |
| `~/Pictures`     | `pcloud:Pictures`  |
| `~/eBooks`       | `eBooks:`          |

The `eBooks:` crypt remote encrypts file contents while intentionally leaving
filenames and directory structure visible.

This is synchronization, not a complete backup. Destination-only files can be
deleted so the remote matches the local source. Recovery relies on pCloud Trash
and file history; no `--backup-dir` archive is maintained.

Only one laptop may be the active writer.

## Managed and local state

Chezmoi manages:

```text
~/.local/bin/rclone-hourly-sync
~/.local/bin/rclone-sync-status
~/.config/systemd/user/rclone-hourly-sync.service
~/.config/systemd/user/rclone-hourly-sync.timer
~/.config/systemd/user/rclone-sync-notify.service
~/.config/rclone/rclone.conf
```

Machine-local state is not managed:

```text
~/.config/rclone-sync/enabled
~/.local/state/rclone-sync/status
~/.config/age/key.txt
```

## Normal operation

Check status:

```fish
rclone-sync-status
```

A healthy writer reports:

```text
Rclone role: PRIMARY WRITER
Last result: SUCCESS
```

A completed oneshot service is normally `inactive (dead)` with `Result=success`.

Run a manual sync:

```fish
systemctl --user start rclone-hourly-sync.service
rclone-sync-status
```

View recent logs:

```fish
journalctl --user \
    -u rclone-hourly-sync.service \
    -n 100 \
    --no-pager
```

Check the schedule:

```fish
systemctl --user list-timers \
    rclone-hourly-sync.timer \
    --all \
    --no-pager
```

## Restore a fresh installation

### 1. Restore chezmoi and the rclone configuration

Restore `~/.config/age/key.txt`, initialize chezmoi, and verify:

```fish
chezmoi init --apply \
    git@github.com:bobby-welch/dotfiles.git

stat -c '%A %a %U:%G %n' \
    ~/.config/rclone/rclone.conf

rclone listremotes
rclone about pcloud:
rclone lsf eBooks: --max-depth 1 | head -n 20
```

Expected remotes:

```text
pcloud:
eBooks:
```

The rclone configuration should have mode `600`.

### 2. Restore the synchronized directories

```fish
mkdir -p ~/Documents ~/Pictures ~/eBooks

rclone copy pcloud:Documents ~/Documents --progress
rclone copy pcloud:Pictures ~/Pictures --progress
rclone copy eBooks: ~/eBooks --progress
```

Inspect all three directories. They must contain the intended authoritative
local data before synchronization is enabled.

### 3. Confirm writer mode is disabled

```fish
systemctl --user daemon-reload
rclone-sync-status
```

Expected role:

```text
Rclone role: DISABLED
```

### 4. Perform dry runs

```fish
rclone sync \
    ~/Documents \
    pcloud:Documents \
    --dry-run \
    --combined=- \
    --retries=1 \
    --log-level=ERROR

rclone sync \
    ~/Pictures \
    pcloud:Pictures \
    --dry-run \
    --combined=- \
    --retries=1 \
    --log-level=ERROR

rclone sync \
    ~/eBooks \
    eBooks: \
    --dry-run \
    --combined=- \
    --retries=1 \
    --log-level=ERROR
```

Review every upload, replacement, and deletion. Stop if anything is unexpected.

### 5. Designate this laptop as the writer

```fish
mkdir -p ~/.config/rclone-sync

printf '%s\n' \
    "Primary rclone writer: $(hostname)" \
    > ~/.config/rclone-sync/enabled

chmod 600 ~/.config/rclone-sync/enabled
```

Run one manual sync:

```fish
systemctl --user start rclone-hourly-sync.service
rclone-sync-status
```

Proceed only when the last result is `SUCCESS`, then enable the timer:

```fish
systemctl --user enable --now \
    rclone-hourly-sync.timer

rclone-sync-status
```

## Disable writer mode

```fish
systemctl --user disable --now \
    rclone-hourly-sync.timer

systemctl --user stop \
    rclone-hourly-sync.service

rm -f ~/.config/rclone-sync/enabled
rclone-sync-status
```

Expected role:

```text
Rclone role: DISABLED
```

## Hand off to another laptop

Never leave two writers enabled.

On the old writer:

```fish
systemctl --user start rclone-hourly-sync.service
rclone-sync-status

systemctl --user disable --now \
    rclone-hourly-sync.timer

rm -f ~/.config/rclone-sync/enabled
```

Confirm the final sync succeeded and the old laptop reports `DISABLED`.

On the new laptop:

1. Restore and inspect the remote data.
2. Run all three dry runs.
3. Create the writer marker.
4. Run one successful manual sync.
5. Enable the timer.

## Failure recovery

Stop automatic activity while investigating:

```fish
systemctl --user disable --now \
    rclone-hourly-sync.timer

systemctl --user stop \
    rclone-hourly-sync.service
```

Inspect status and logs:

```fish
rclone-sync-status

journalctl --user \
    -u rclone-hourly-sync.service \
    -n 200 \
    --no-pager
```

Verify remote access:

```fish
rclone about pcloud:
rclone lsf eBooks: --max-depth 1 | head -n 20
```

Before retrying, run dry runs for every affected directory. Re-enable the timer
only after a manual sync completes successfully.

## Deletion protection

The managed sync uses `--max-delete=100`. A run that would exceed the limit
fails instead of completing the deletions.

Do not raise or bypass the limit until the proposed changes have been reviewed
with a dry run. Restore accidentally deleted remote data through pCloud Trash or
file history before running another sync.

## Security

- Back up `~/.config/age/key.txt` securely in 1Password.
- Never commit the age identity or plaintext rclone configuration.
- Keep `~/.config/rclone/rclone.conf` and the writer marker at mode `600`.
- Do not share logs before reviewing remote names and paths.
