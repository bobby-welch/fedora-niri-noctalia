# SSH and GitHub Setup

Use one device-specific SSH key per laptop. Never copy a private SSH key from
another computer.

## Set up a new laptop

Enable the systemd user SSH-agent socket:

```fish
systemctl --user enable --now ssh-agent.socket
```

Create the key:

```fish
mkdir -p ~/.ssh
chmod 700 ~/.ssh

ssh-keygen \
    -t ed25519 \
    -C "bobby@$(hostname)" \
    -f ~/.ssh/id_ed25519
```

Use a strong passphrase and save it in 1Password. Set the expected permissions:

```fish
chmod 600 ~/.ssh/id_ed25519
chmod 644 ~/.ssh/id_ed25519.pub
```

Display the public key:

```fish
cat ~/.ssh/id_ed25519.pub
```

In GitHub, open **Settings → SSH and GPG keys**, create a new authentication
key, give it a device-specific name, and paste the complete public key.

Only the `.pub` file may be shared. Never expose `~/.ssh/id_ed25519`.

## Managed SSH configuration

Chezmoi manages `~/.ssh/config`:

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

After applying chezmoi, verify the resolved settings:

```fish
ssh -G github.com 2>/dev/null \
    | rg '^(hostname|user|identityfile|identitiesonly|'\
'addkeystoagent|forwardagent) '
```

Expected essentials:

```text
user git
hostname github.com
identityfile ~/.ssh/id_ed25519
identitiesonly yes
addkeystoagent true
forwardagent no
```

## Test GitHub authentication

```fish
ssh -T git@github.com
```

On first use, verify GitHub's displayed host-key fingerprint against GitHub's
published fingerprints before accepting it.

A successful test recognizes the account and says shell access is not provided.
GitHub intentionally exits with status `1`, so judge the result by the message.

## Normal operation

The first SSH operation after login may request the key passphrase. Later
operations in that login session should reuse the key through the agent.

```fish
ssh-add -l
```

Manually load the key when needed:

```fish
ssh-add ~/.ssh/id_ed25519
```

Remove all loaded keys from the current agent:

```fish
ssh-add -D
```

## Retire a laptop

1. Run any final repository pushes from the old laptop.
2. Identify its public-key fingerprint:

   ```fish
   ssh-keygen -lf ~/.ssh/id_ed25519.pub
   ```

3. Remove only that laptop's key from GitHub.
4. Disable or erase the old laptop securely.

## Troubleshooting

Check the socket and environment:

```fish
systemctl --user status ssh-agent.socket \
    --no-pager \
    --lines=0

echo $SSH_AUTH_SOCK
```

Expected socket form:

```text
/run/user/1000/ssh-agent.socket
```

The numeric user ID may differ.

Restart the agent environment:

```fish
systemctl --user restart ssh-agent.socket
exec fish
```

Inspect key selection:

```fish
ssh -G github.com 2>/dev/null \
    | rg '^(user|hostname|identityfile|identitiesonly) '
```

Use verbose output only for troubleshooting and review it before sharing:

```fish
ssh -vT git@github.com
```
