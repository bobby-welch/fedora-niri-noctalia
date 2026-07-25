# Install or update Harper's language server from the latest stable release.
update-harper:
    #!/usr/bin/env bash
    set -euo pipefail

    # Use Harper's official Linux x86-64 release archive.
    readonly archive='harper-ls-x86_64-unknown-linux-gnu.tar.gz'
    readonly url="https://github.com/Automattic/harper/releases/latest/download/${archive}"

    # Create temporary workspace and remove it on exit.
    tmpdir=$(mktemp -d)
    trap 'rm -rf "$tmpdir"' EXIT

    # Download the latest stable release.
    printf '%s\n' 'Downloading the latest harper-ls release...'
    curl --fail --location --silent --show-error \
        --output "$tmpdir/$archive" \
        "$url"

    # Extract the language-server binary.
    tar \
        --extract \
        --gzip \
        --file "$tmpdir/$archive" \
        --directory "$tmpdir"

    # Ensure the user-local binary directory exists.
    mkdir -p "$HOME/.local/bin"

    # Install or replace the existing binary.
    install \
        --mode=0755 \
        "$tmpdir/harper-ls" \
        "$HOME/.local/bin/harper-ls"

    # Confirm the installed version.
    printf '\n%s\n' 'Installed:'
    "$HOME/.local/bin/harper-ls" --version
