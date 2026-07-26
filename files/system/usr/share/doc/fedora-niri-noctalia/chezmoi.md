# Chezmoi Setup and Workflow

Chezmoi manages the user configuration stored in:

```text
git@github.com:bobby-welch/dotfiles.git
```

Source directory:

```text
~/.local/share/chezmoi
```

## Restore a new laptop

Complete these steps in order:

1. Configure GitHub SSH access.
2. Restore the age identity.
3. Initialize and apply chezmoi.
4. Reload the user manager and shell.
5. Run `chezmoi-audit`.

### Restore the age identity

Restore the 1Password document named `Chezmoi age identity key` to:

```text
~/.config/age/key.txt
```

Secure and verify it:

```fish
mkdir -p ~/.config/age
chmod 600 ~/.config/age/key.txt
age-keygen -y ~/.config/age/key.txt
```

Expected recipient:

```text
age1gdv6nj37ekn2v3r7pw907ujvzhujgeghnsqw8umeyk0tm0v38y3sg542zj
```

Stop if it differs. Never commit the private age identity.

### Initialize and apply

```fish
chezmoi init --apply \
    git@github.com:bobby-welch/dotfiles.git

systemctl --user daemon-reload
systemctl --user enable --now ssh-agent.socket
exec fish
```

Verify:

```fish
chezmoi-audit
```

A clean audit exits with status `0`.

## Normal edit workflow

### Edit the live file

```fish
nvim ~/.config/example/config
chezmoi add ~/.config/example/config
```

Review both destination and source state:

```fish
chezmoi diff
git -C ~/.local/share/chezmoi diff
git -C ~/.local/share/chezmoi status
```

Commit and push the generated source path:

```fish
git -C ~/.local/share/chezmoi add <source-path>

git -C ~/.local/share/chezmoi commit \
    -m "Describe the change"

git -C ~/.local/share/chezmoi push
```

Finish with:

```fish
chezmoi-audit
```

### Edit the source directly

```fish
chezmoi edit ~/.config/example/config
chezmoi apply ~/.config/example/config
chezmoi-audit
```

### Pull remote changes

Use the review-first workflow:

```fish
git -C ~/.local/share/chezmoi pull --ff-only
chezmoi diff
chezmoi apply
chezmoi-audit
```

Use `chezmoi update` only when the remote changes are already trusted and should
be pulled and applied in one operation.

## Common operations

Inspect state:

```fish
chezmoi status
chezmoi diff
chezmoi managed
```

Show the rendered destination or source mapping:

```fish
chezmoi cat ~/.config/example/config
chezmoi source-path ~/.config/example/config
```

Add a normal file:

```fish
chezmoi add ~/.config/example/config
```

Add an executable:

```fish
chmod +x ~/.local/bin/example
chezmoi add ~/.local/bin/example
```

Add or update a secret:

```fish
chezmoi add --encrypt ~/.config/example/secret.conf
```

Never stage a plaintext secret directly with Git.

Stop managing a file while leaving the destination in place:

```fish
chezmoi forget ~/.config/example/config
```

## Encrypted rclone configuration

The encrypted source is applied as:

```text
~/.config/rclone/rclone.conf
```

Verify that the rendered source matches the live file:

```fish
sha256sum ~/.config/rclone/rclone.conf

chezmoi cat ~/.config/rclone/rclone.conf \
    | sha256sum
```

The hashes should match.

## dconf settings

The source-only file `dconf.ini` is loaded by a `run_onchange` chezmoi script.
Edit it in the source repository:

```fish
nvim ~/.local/share/chezmoi/dconf.ini
git -C ~/.local/share/chezmoi diff -- dconf.ini
```

Preview and apply scripts:

```fish
chezmoi apply --dry-run --verbose --include=scripts
chezmoi apply --include=scripts
```

## Machine-specific state

Chezmoi intentionally does not manage:

```text
~/.ssh/id_ed25519
~/.ssh/id_ed25519.pub
~/.ssh/known_hosts
~/.config/age/key.txt
~/.config/rclone-sync/enabled
~/.local/state/rclone-sync/status
```

Do not add machine identity, runtime state, or the rclone writer marker to the
repository.

## Scripts and templates

Template sources end in `.tmpl`. Test one with:

```fish
chezmoi execute-template \
    < ~/.local/share/chezmoi/example.tmpl
```

Chezmoi scripts live under `.chezmoiscripts/`. Prefer declarative files over
scripts, and use `run_once` or `run_onchange` only when the lifecycle requires
it. Scripts must not silently enable machine-specific services.

## Recovery

Preview before repairing:

```fish
chezmoi status
chezmoi diff
```

Restore the managed state:

```fish
chezmoi apply
systemctl --user daemon-reload
exec fish
chezmoi-audit
```

For source repository problems:

```fish
git -C ~/.local/share/chezmoi status
git -C ~/.local/share/chezmoi diff
```

Do not reset or discard changes until they have been reviewed.
