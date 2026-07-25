# Create the Node.js tools container and export its commands.
setup-node-tools:
    distrobox assemble create \
        --file /usr/share/fedora-niri-noctalia/distrobox/node-tools.ini

# Update markdownlint-cli2 to the latest stable release.
update-markdownlint:
    #!/usr/bin/env bash
    set -euo pipefail

    # Update the package non-interactively inside node-tools.
    distrobox enter \
        --no-tty \
        --name node-tools \
        -- \
        sudo npm install \
            --global \
            --prefix /usr/local \
            markdownlint-cli2@latest

    # Re-export the wrapper if it is missing or stale.
    distrobox enter \
        --no-tty \
        --name node-tools \
        -- \
        distrobox-export \
            --bin /usr/local/bin/markdownlint-cli2 \
            --export-path "$HOME/.local/bin"

    # Confirm the host-visible version.
    printf '\n%s\n' 'Installed:'
    "$HOME/.local/bin/markdownlint-cli2" --version
