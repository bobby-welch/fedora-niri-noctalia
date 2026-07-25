# Chezmoi Setup and Workflow

This guide covers restoring, applying, updating, and maintaining the dotfiles
repository.

Repository:

```text
git@github.com:bobby-welch/dotfiles.git
```

Chezmoi source directory:

```text
~/.local/share/chezmoi
```

Local chezmoi configuration:

```text
~/.config/chezmoi/chezmoi.toml
```

## Bootstrap order

On a new or rebuilt machine, complete these steps in order:

1. Configure SSH and GitHub access.
2. Restore the age identity from 1Password.
3. Initialize and apply the dotfiles repository.
4. Verify that chezmoi reports no differences.
5. Reload and verify user services.
6. Enable machine-specific services only when appropriate.

See [SSH and GitHub Setup](ssh-github.md) before continuing on a fresh machine.

## 1. Restore the age identity

The repository contains an age-encrypted rclone configuration. Chezmoi cannot
apply it until the matching private age identity is available.

Restore the 1Password document named:

```text
Chezmoi age identity key
```

to:

```text
~/.config/age/key.txt
```

Create the directory if needed:

```fish
mkdir -p ~/.config/age
```

Secure the identity:

```fish
chmod 600 ~/.config/age/key.txt
```

Verify its public recipient:

```fish
age-keygen -y ~/.config/age/key.txt
```

Expected value:

```text
age1gdv6nj37ekn2v3r7pw907ujvzhujgeghnsqw8umeyk0tm0v38y3sg542zj
```

Do not continue if the value differs.

The private age identity must never be committed to Git.

## 2. Initialize and apply chezmoi

After GitHub SSH authentication and the age identity are ready:

```fish
chezmoi init --apply git@github.com:bobby-welch/dotfiles.git
```

This command:

- clones the dotfiles repository;
- renders the local chezmoi configuration;
- decrypts encrypted source files;
- installs managed files;
- runs applicable chezmoi scripts.

The repository contains:

```text
.chezmoi.toml.tmpl
```

It renders the local configuration using:

```text
~/.config/age/key.txt
```

The generated configuration should contain:

```toml
encryption = "age"

[age]
identity = "/home/bobby/.config/age/key.txt"
recipient = "age1gdv6nj37ekn2v3r7pw907ujvzhujgeghnsqw8umeyk0tm0v38y3sg542zj"
```

## 3. Verify the initial apply

Check for unmanaged differences:

```fish
chezmoi status
```

A clean system produces no output.

Check the repository:

```fish
git -C ~/.local/share/chezmoi status
```

Expected result:

```text
nothing to commit, working tree clean
```

Verify the configured paths:

```fish
chezmoi source-path
chezmoi data | rg '"(sourceDir|configFile|encryption|identity|recipient)"'
```

## Encrypted files

The encrypted source currently managed by chezmoi is:

```text
private_dot_config/rclone/encrypted_private_rclone.conf.age
```

It is applied as:

```text
~/.config/rclone/rclone.conf
```

Chezmoi decrypts the file during operations such as:

```fish
chezmoi apply
chezmoi diff
chezmoi status
```

To verify that the encrypted source matches the live file:

```fish
sha256sum ~/.config/rclone/rclone.conf

chezmoi cat ~/.config/rclone/rclone.conf \
    | sha256sum
```

The hashes should match.

Never use ordinary `git add` on a plaintext secret.

To add or update a sensitive file through chezmoi, use encryption explicitly:

```fish
chezmoi add --encrypt ~/.config/rclone/rclone.conf
```

## dconf handling

The repository contains:

```text
dconf.ini
```

It is not applied as a normal file because `.chezmoiignore` contains:

```text
/dconf.ini
```

Instead, this script loads it into dconf:

```text
.chezmoiscripts/run_onchange_after_load-dconf.sh.tmpl
```

The script includes a hash of `dconf.ini`. Chezmoi reruns it only when the dconf
export changes.

To update the managed dconf data:

```fish
dconf dump / > ~/.local/share/chezmoi/dconf.ini
```

Review the result before committing:

```fish
git -C ~/.local/share/chezmoi diff -- dconf.ini
```

Then apply it locally if needed:

```fish
chezmoi apply
```

## System documentation

The quick-install and detailed recovery guides are maintained in the BlueBuild
repository and installed with the image at:

```text
/usr/share/doc/fedora-niri-noctalia/
```

They are available immediately after boot, before SSH, GitHub, age, or chezmoi
has been configured.

The chezmoi repository contains only managed user configuration and related
source files.

## Normal update workflow

### Update a managed file

Edit the live file normally, then add the change back to chezmoi:

```fish
chezmoi add ~/.config/example/config
```

Review:

```fish
chezmoi diff
git -C ~/.local/share/chezmoi diff
```

Stage, commit, and push:

```fish
git -C ~/.local/share/chezmoi add <source-path>

git -C ~/.local/share/chezmoi commit \
    -m "Describe the change"

git -C ~/.local/share/chezmoi push
```

### Edit the source directly

Open the managed source file:

```fish
chezmoi edit ~/.config/example/config
```

Apply it:

```fish
chezmoi apply ~/.config/example/config
```

Verify:

```fish
chezmoi status
```

### Pull and apply remote changes

Use the review-first workflow by default:

```fish
git -C ~/.local/share/chezmoi pull --ff-only
chezmoi diff
chezmoi apply
```

This keeps retrieval and application separate so remote changes can be reviewed
before they affect the home directory.

For a trusted change set that should be pulled and applied in one step:

```fish
chezmoi update
```

## Inspect managed state

Show pending differences:

```fish
chezmoi status
```

Preview changes:

```fish
chezmoi diff
```

Show the rendered version of a managed file:

```fish
chezmoi cat ~/.config/example/config
```

Show the source path corresponding to a destination:

```fish
chezmoi source-path ~/.config/example/config
```

Show the destination corresponding to a source file:

```fish
chezmoi target-path \
    ~/.local/share/chezmoi/private_dot_config/example/config
```

List managed destination files:

```fish
chezmoi managed
```

## Add a new file

For a normal configuration file:

```fish
chezmoi add ~/.config/example/config
```

For an executable script:

```fish
chmod +x ~/.local/bin/example
chezmoi add ~/.local/bin/example
```

For a sensitive file:

```fish
chezmoi add --encrypt ~/.config/example/secret.conf
```

Always inspect the generated source path before committing.

## Remove a managed file

Remove it from chezmoi while leaving the live destination in place:

```fish
chezmoi forget ~/.config/example/config
```

To remove both the source entry and destination, inspect the change carefully
and remove them deliberately rather than assuming `forget` deletes the live
file.

## Templates

Files ending in:

```text
.tmpl
```

are rendered through chezmoi templates.

Test a template directly:

```fish
chezmoi execute-template \
    < ~/.local/share/chezmoi/example.tmpl
```

Inspect template data:

```fish
chezmoi data
```

Do not place secrets directly into a template committed to Git.

## Scripts

Chezmoi scripts live under:

```text
.chezmoiscripts/
```

Common prefixes include:

```text
run_once_
run_onchange_
run_before_
run_after_
```

The current dconf loader is:

```text
run_onchange_after_load-dconf.sh.tmpl
```

Before adding a new script, decide whether it should:

- run once per machine;
- rerun when its content changes;
- run before files are applied;
- run after files are applied.

Avoid scripts that silently enable machine-specific services. For example, the
rclone primary-writer marker and timer must remain deliberate manual actions.

## Machine-specific state

The following items are intentionally not managed by chezmoi:

```text
~/.config/age/key.txt
~/.ssh/id_ed25519
~/.ssh/id_ed25519.pub
~/.ssh/known_hosts
~/.config/rclone-sync/enabled
~/.local/state/rclone-sync/status
```

Reasons include:

- private recovery material;
- per-device credentials;
- generated host state;
- runtime state;
- safeguards that should not activate automatically.

## Permissions

Verify sensitive files:

```fish
stat -c '%A %a %U:%G %n' \
    ~/.config/age/key.txt \
    ~/.config/rclone/rclone.conf \
    ~/.ssh/config \
    ~/.ssh/id_ed25519
```

Expected mode for each is:

```text
600
```

The SSH directory itself should be:

```text
700
```

## Post-apply service reload

After applying changes that add or modify systemd user units:

```fish
systemctl --user daemon-reload
```

Inspect failures:

```fish
systemctl --user --failed
```

Do not automatically enable every managed unit. Some services or timers are
machine-specific and should be enabled only after validation.

## Final verification

Run:

```fish
chezmoi status

git -C ~/.local/share/chezmoi status

systemctl --user --failed
```

A healthy result has:

- no chezmoi status output;
- a clean Git working tree;
- no unexpected failed user services.

## Recovery

If the local source directory is damaged but the home-directory files remain
intact:

1. move the source directory aside;
2. ensure GitHub SSH and the age identity work;
3. run `chezmoi init git@github.com:bobby-welch/dotfiles.git`;
4. inspect with `chezmoi diff`;
5. apply only after reviewing the proposed changes.

Do not delete the existing source directory until the replacement has been
verified.
