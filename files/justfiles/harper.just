# Install or update Harper's language server from the latest stable release.
update-harper:
    #!/usr/bin/env bash
    set -euo pipefail

    readonly archive='harper-ls-x86_64-unknown-linux-gnu.tar.gz'
    readonly url="https://github.com/Automattic/harper/releases/latest/download/${archive}"

    tmpdir=$(mktemp -d)
    trap 'rm -rf "$tmpdir"' EXIT

    printf '%s\n' 'Downloading the latest harper-ls release...'
    curl --fail --location --silent --show-error \
        --output "$tmpdir/$archive" \
        "$url"

    tar \
        --extract \
        --gzip \
        --file "$tmpdir/$archive" \
        --directory "$tmpdir"

    install \
        --mode=0755 \
        "$tmpdir/harper-ls" \
        "$HOME/.local/bin/harper-ls"

    printf '\n%s\n' 'Installed:'
    "$HOME/.local/bin/harper-ls" --version
