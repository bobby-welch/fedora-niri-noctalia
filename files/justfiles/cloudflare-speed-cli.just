# Install or update cloudflare-speed-cli from the latest stable release.
update-cloudflare-speed-cli:
    #!/usr/bin/env bash
    set -euo pipefail

    # Select the official static Linux archive for this architecture.
    case $(uname -m) in
        x86_64)
            readonly target='x86_64-unknown-linux-musl'
            ;;
        aarch64 | arm64)
            readonly target='aarch64-unknown-linux-musl'
            ;;
        *)
            printf 'Unsupported architecture: %s\n' "$(uname -m)" >&2
            exit 1
            ;;
    esac

    readonly archive="cloudflare-speed-cli-${target}.tar.xz"
    readonly base_url='https://github.com/kavehtehrani/cloudflare-speed-cli/releases/latest/download'
    readonly archive_url="${base_url}/${archive}"
    readonly checksum_url="${archive_url}.sha256"

    # Create temporary workspace and remove it on exit.
    tmpdir=$(mktemp -d)
    trap 'rm -rf "$tmpdir"' EXIT

    # Download the release archive and its official checksum.
    printf '%s\n' 'Downloading the latest cloudflare-speed-cli release...'
    curl --fail --location --silent --show-error \
        --output "$tmpdir/$archive" \
        "$archive_url"

    curl --fail --location --silent --show-error \
        --output "$tmpdir/$archive.sha256" \
        "$checksum_url"

    # Verify the downloaded archive before extracting it.
    expected_checksum=$(awk 'NR == 1 { print $1 }' "$tmpdir/$archive.sha256")
    actual_checksum=$(sha256sum "$tmpdir/$archive" | awk '{ print $1 }')

    if [[ -z $expected_checksum || $actual_checksum != "$expected_checksum" ]]; then
        printf '%s\n' 'Checksum verification failed.' >&2
        exit 1
    fi

    # Extract and locate the executable.
    tar \
        --extract \
        --xz \
        --file "$tmpdir/$archive" \
        --directory "$tmpdir"

    binary=$(find "$tmpdir" \
        -type f \
        -name cloudflare-speed-cli \
        -print \
        -quit)

    if [[ -z $binary ]]; then
        printf '%s\n' 'The release archive did not contain cloudflare-speed-cli.' >&2
        exit 1
    fi

    # Install or replace the user-local executable.
    mkdir -p "$HOME/.local/bin"

    install \
        --mode=0755 \
        "$binary" \
        "$HOME/.local/bin/cloudflare-speed-cli"

    # Confirm the installed version.
    printf '\n%s\n' 'Installed:'
    "$HOME/.local/bin/cloudflare-speed-cli" --version
