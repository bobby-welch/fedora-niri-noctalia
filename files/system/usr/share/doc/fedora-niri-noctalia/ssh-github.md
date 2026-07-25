# SSH and GitHub Setup

This guide configures SSH authentication for GitHub on a new or rebuilt laptop.

Each laptop should have its own SSH key. Do not copy a private SSH key from
another computer.

## 1. Verify the SSH agent

The Fedora image provides a systemd user SSH-agent socket.

Enable and start it:

```fish
systemctl --user enable --now ssh-agent.socket
```

Verify:

```fish
systemctl --user status ssh-agent.socket \
    --no-pager \
    --lines=0
```

The socket should be active and listening at:

```text
$XDG_RUNTIME_DIR/ssh-agent.socket
```

The managed Fish configuration sets `SSH_AUTH_SOCK` automatically when that
socket exists.

Confirm:

```fish
echo $SSH_AUTH_SOCK
```

Expected form:

```text
/run/user/1000/ssh-agent.socket
```

The numeric user ID may differ.

## 2. Generate a device-specific SSH key

Check whether a key already exists:

```fish
ls -l ~/.ssh/id_ed25519 ~/.ssh/id_ed25519.pub 2>/dev/null
```

On a new machine, create a new Ed25519 key:

```fish
mkdir -p ~/.ssh
chmod 700 ~/.ssh

ssh-keygen \
    -t ed25519 \
    -C "bobby@$(hostname)" \
    -f ~/.ssh/id_ed25519
```

Use a strong passphrase and save it in 1Password.

Do not copy `id_ed25519` from another laptop.

Set the expected permissions:

```fish
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_ed25519
chmod 644 ~/.ssh/id_ed25519.pub
```

## 3. Add the public key to GitHub

Display the public key:

```fish
cat ~/.ssh/id_ed25519.pub
```

In GitHub:

1. Open **Settings**.
2. Open **SSH and GPG keys**.
3. Select **New SSH key**.
4. Choose **Authentication Key**.
5. Give the key a recognizable device name.
6. Paste the complete public key.
7. Save it.

Only the `.pub` file may be uploaded or shared. Never expose the private key.

## 4. Apply the SSH client configuration

Chezmoi manages:

```text
~/.ssh/config
```

The managed configuration is:

```sshconfig
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519
    IdentitiesOnly yes
    AddKeysToAgent yes

Host *
    ForwardAgent no
```

This configuration:

- uses the correct GitHub SSH username;
- selects the device’s Ed25519 key;
- adds the key to the running agent after use;
- prevents unrelated hosts from using the GitHub key automatically;
- disables SSH-agent forwarding.

After chezmoi applies the file, verify its permissions:

```fish
stat -c '%A %a %U:%G %n' ~/.ssh/config
```

Expected mode:

```text
600
```

## 5. Verify the resolved configuration

```fish
ssh -G github.com 2>/dev/null \
    | rg '^(hostname|user|identityfile|identitiesonly|'\
'addkeystoagent|forwardagent) '
```

Expected essentials:

```text
user git
hostname github.com
identitiesonly yes
identityfile ~/.ssh/id_ed25519
addkeystoagent true
forwardagent no
```

## 6. Test GitHub authentication

```fish
ssh -T git@github.com
```

On the first connection, SSH may ask whether to trust GitHub’s host key.

Verify the displayed fingerprint against GitHub’s published fingerprints before
accepting it.

A successful authentication reports that GitHub recognized the account but does
not provide shell access. GitHub intentionally returns exit status `1` for this
test even when authentication succeeds, so judge the result by the message.

## 7. Verify the dotfiles repository

Check the repository remote:

```fish
git -C ~/.local/share/chezmoi remote -v
```

Expected remote:

```text
git@github.com:bobby-welch/dotfiles.git
```

Test access without changing the repository:

```fish
git -C ~/.local/share/chezmoi fetch --dry-run
```

## Normal operation

The first SSH operation after login may request the key passphrase. Because
`AddKeysToAgent` is enabled, later operations in that login session should reuse
the unlocked key.

List loaded keys:

```fish
ssh-add -l
```

Remove all loaded keys from the current agent:

```fish
ssh-add -D
```

Manually load the GitHub key:

```fish
ssh-add ~/.ssh/id_ed25519
```

## Replacing or retiring a laptop

When retiring a laptop:

1. Disable or erase the old laptop securely.
2. Remove that laptop’s public key from GitHub.
3. Leave other device-specific keys in place.

To identify the local public-key fingerprint:

```fish
ssh-keygen -lf ~/.ssh/id_ed25519.pub
```

Compare it with the key entry shown in GitHub before deleting anything.

## Files and ownership

Expected local files:

```text
~/.ssh/config
~/.ssh/id_ed25519
~/.ssh/id_ed25519.pub
~/.ssh/known_hosts
```

Expected permissions:

| Path                    |           Mode |
| ----------------------- | -------------: |
| `~/.ssh`                |          `700` |
| `~/.ssh/config`         |          `600` |
| `~/.ssh/id_ed25519`     |          `600` |
| `~/.ssh/id_ed25519.pub` |          `644` |
| `~/.ssh/known_hosts`    | `600` or `644` |

Chezmoi manages only:

```text
~/.ssh/config
```

The private key, public key, and `known_hosts` remain machine-specific.

## Troubleshooting

### No SSH agent is available

```fish
systemctl --user restart ssh-agent.socket
exec fish
echo $SSH_AUTH_SOCK
```

### The key is not loaded

```fish
ssh-add ~/.ssh/id_ed25519
ssh-add -l
```

### GitHub uses the wrong username or key

Inspect the resolved configuration:

```fish
ssh -G github.com 2>/dev/null \
    | rg '^(user|hostname|identityfile|identitiesonly) '
```

The user must be `git`, and the identity should be `~/.ssh/id_ed25519`.

### Test with detailed SSH output

```fish
ssh -vT git@github.com
```

The verbose output may include filenames and connection details. Do not publish
it without reviewing it for sensitive information.
