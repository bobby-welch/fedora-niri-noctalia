# Verify the installed workstation without changing it.
system-audit:
    #!/usr/bin/env bash
    set -uo pipefail

    # Read-only summary of deployment, desktop, services, SSH,
    # chezmoi, rclone, and the local BlueBuild repository.

    readonly EXPECTED_IMAGE='ghcr.io/bobby-welch/fedora-niri-noctalia:latest'
    readonly RCLONE_MARKER="$HOME/.config/rclone-sync/enabled"
    readonly RCLONE_STATE="$HOME/.local/state/rclone-sync/status"
    readonly RCLONE_TIMER='rclone-hourly-sync.timer'
    readonly IMAGE_REPOSITORY="$HOME/.local/src/fedora-niri-noctalia"

    pass_count=0
    warn_count=0
    fail_count=0
    skip_count=0

    # Use color only in an interactive terminal.
    if [[ -t 1 && -z ${NO_COLOR:-} ]] \
        && command -v tput >/dev/null 2>&1; then
        readonly RESET=$(tput sgr0)
        readonly BOLD=$(tput bold)
        readonly RED=$(tput setaf 1)
        readonly GREEN=$(tput setaf 2)
        readonly YELLOW=$(tput setaf 3)
        readonly CYAN=$(tput setaf 6)
    else
        readonly RESET=''
        readonly BOLD=''
        readonly RED=''
        readonly GREEN=''
        readonly YELLOW=''
        readonly CYAN=''
    fi

    heading() {
        printf '\n%s%s== %s ==%s\n' \
            "$BOLD" "$CYAN" "$1" "$RESET"
    }

    pass() {
        printf '  %sPASS%s  %s\n' "$GREEN" "$RESET" "$1"
        pass_count=$((pass_count + 1))
    }

    warn() {
        printf '  %sWARN%s  %s\n' "$YELLOW" "$RESET" "$1"
        warn_count=$((warn_count + 1))
    }

    fail() {
        printf '  %sFAIL%s  %s\n' "$RED" "$RESET" "$1"
        fail_count=$((fail_count + 1))
    }

    skip() {
        printf '  %sSKIP%s  %s\n' "$CYAN" "$RESET" "$1"
        skip_count=$((skip_count + 1))
    }

    command_exists() {
        command -v "$1" >/dev/null 2>&1
    }

    # Verify the booted image and report a staged deployment.
    heading 'Deployment'

    if ! command_exists rpm-ostree; then
        fail 'rpm-ostree is not installed'
    elif ! command_exists python3; then
        fail 'python3 is not installed'
    else
        deployment_status=$(
            rpm-ostree status --json 2>/dev/null \
                | python3 -c 'import json, sys; deployments = json.load(sys.stdin).get("deployments", []); booted = next((item for item in deployments if item.get("booted")), None); booted is not None or sys.exit(1); image = booted.get("container-image-reference") or booted.get("origin") or ""; prefixes = ("ostree-image-signed:docker://", "ostree-image-signed:registry:", "ostree-unverified-image:docker://", "ostree-unverified-registry:"); image = next((image[len(prefix):] for prefix in prefixes if image.startswith(prefix)), image); staged = any(item.get("staged", False) for item in deployments); print(f"{image}\t{str(staged).lower()}")'
        )
        deployment_exit=$?

        if ((deployment_exit != 0)); then
            fail 'Unable to read the deployment status'
        else
            IFS=$'\t' read -r booted_image staged \
                <<<"$deployment_status"

            if [[ $booted_image == "$EXPECTED_IMAGE" ]]; then
                pass 'Expected BlueBuild image is booted'
            elif [[ -z $booted_image ]]; then
                fail 'Unable to determine the booted image'
            else
                fail "Unexpected booted image: $booted_image"
            fi

            if [[ $staged == true ]]; then
                warn 'A newer deployment is staged; reboot when convenient'
            else
                pass 'No staged deployment is waiting'
            fi
        fi
    fi

    # Report failed systemd user units.
    heading 'User services'

    failed_units=$(
        systemctl --user --failed --no-legend --plain 2>/dev/null \
            || true
    )

    if [[ -z $failed_units ]]; then
        pass 'No failed user units'
    else
        fail 'One or more user units have failed'
        printf '%s\n' "$failed_units" \
            | sed 's/^/        /'
    fi

    # Validate the active desktop configuration.
    heading 'Desktop'

    if niri validate >/dev/null 2>&1; then
        pass 'Niri configuration is valid'
    else
        fail 'Niri configuration is invalid'
    fi

    if noctalia config validate >/dev/null 2>&1; then
        pass 'Noctalia configuration is valid'
    else
        fail 'Noctalia configuration is invalid'
    fi

    if pgrep -x noctalia >/dev/null 2>&1; then
        pass 'Noctalia is running'
    else
        fail 'Noctalia is not running'
    fi

    # Require the SSH agent only after a device key exists.
    heading 'SSH'

    if [[ ! -f $HOME/.ssh/id_ed25519 ]]; then
        skip 'GitHub SSH key has not been created'
    else
        if systemctl --user is-enabled --quiet \
            ssh-agent.socket 2>/dev/null; then
            pass 'SSH-agent socket is enabled'
        else
            fail 'SSH-agent socket is not enabled'
        fi

        if systemctl --user is-active --quiet \
            ssh-agent.socket 2>/dev/null; then
            pass 'SSH-agent socket is active'
        else
            fail 'SSH-agent socket is not active'
        fi
    fi

    # Summarize the dedicated chezmoi audit.
    heading 'Chezmoi'

    if [[ ! -d $HOME/.local/share/chezmoi ]]; then
        skip 'Chezmoi has not been initialized'
    elif ! command_exists chezmoi-audit; then
        fail 'chezmoi-audit is not installed'
    elif chezmoi-audit >/dev/null 2>&1; then
        pass 'Chezmoi audit is clean'
    else
        fail 'Chezmoi audit found problems; run chezmoi-audit'
    fi

    # Check rclone only when this laptop is the designated writer.
    heading 'Rclone'

    if [[ ! -f $RCLONE_MARKER ]]; then
        skip 'Rclone writer is disabled'
    else
        if systemctl --user is-enabled --quiet \
            "$RCLONE_TIMER" 2>/dev/null; then
            pass 'Rclone timer is enabled'
        else
            fail 'Rclone timer is not enabled'
        fi

        if systemctl --user is-active --quiet \
            "$RCLONE_TIMER" 2>/dev/null; then
            pass 'Rclone timer is active'
        else
            fail 'Rclone timer is not active'
        fi

        if [[ ! -r $RCLONE_STATE ]]; then
            fail 'Rclone status file is missing'
        else
            rclone_result=$(
                sed -n 's/^RESULT=//p' "$RCLONE_STATE" \
                    | tr -d "\"'" \
                    | head -n 1
            )

            if [[ $rclone_result == SUCCESS ]]; then
                pass 'Last rclone sync succeeded'
            else
                fail "Last rclone result is ${rclone_result:-unknown}"
            fi
        fi
    fi

    # Inspect only the local working tree; do not contact GitHub.
    heading 'BlueBuild repository'

    if [[ ! -d $IMAGE_REPOSITORY/.git ]]; then
        skip 'BlueBuild source repository is not cloned'
    else
        repository_changes=$(
            git -C "$IMAGE_REPOSITORY" status --short 2>/dev/null \
                || true
        )

        if [[ -z $repository_changes ]]; then
            pass 'BlueBuild repository working tree is clean'
        else
            warn 'BlueBuild repository has uncommitted changes'
            printf '%s\n' "$repository_changes" \
                | sed 's/^/        /'
        fi
    fi

    heading 'Summary'

    printf '  %s%d passed%s, %s%d warnings%s, %s%d skipped%s, %s%d failed%s\n' \
        "$GREEN" "$pass_count" "$RESET" \
        "$YELLOW" "$warn_count" "$RESET" \
        "$CYAN" "$skip_count" "$RESET" \
        "$RED" "$fail_count" "$RESET"

    if ((fail_count > 0)); then
        exit 1
    fi
