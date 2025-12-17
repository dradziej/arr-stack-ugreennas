#!/bin/bash
# Check if local .env.nas.backup matches NAS .env
# Warns if out of sync (non-blocking)

check_env_backup() {
    local repo_root
    repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || repo_root="."

    local backup_file="$repo_root/.env.nas.backup"

    # Skip if no backup file
    if [[ ! -f "$backup_file" ]]; then
        echo "    SKIP: No .env.nas.backup file"
        return 0
    fi

    # Try to reach NAS (quick timeout)
    if ! timeout 2 ping -c 1 yournas.local &>/dev/null && ! timeout 2 ping -c 1 192.168.1.100 &>/dev/null; then
        echo "    SKIP: NAS not reachable"
        return 0
    fi

    # Get NAS .env via SSH
    # Use timeout to prevent hanging if SSH stalls
    # Requires NAS_SSH_PASS env var or SSH key auth
    local nas_env
    if [[ -n "$NAS_SSH_PASS" ]] && command -v sshpass &>/dev/null; then
        nas_env=$(timeout 10 sshpass -p "$NAS_SSH_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 admin@yournas.local "cat /volume1/docker/arr-stack/.env" 2>/dev/null)
    else
        nas_env=$(timeout 10 ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o BatchMode=yes admin@yournas.local "cat /volume1/docker/arr-stack/.env" 2>/dev/null)
    fi

    # Skip if SSH failed or timed out
    if [[ -z "$nas_env" ]]; then
        echo "    SKIP: Could not fetch NAS .env (SSH failed or timed out)"
        return 0
    fi

    # Compare
    local local_env
    local_env=$(cat "$backup_file")

    if [[ "$nas_env" != "$local_env" ]]; then
        echo "    WARNING: .env.nas.backup differs from NAS .env"
        echo "             Run: scp admin@yournas.local:/volume1/docker/arr-stack/.env .env.nas.backup"
        return 0  # Warning only, don't block
    fi

    echo "    OK: .env.nas.backup matches NAS"
    return 0
}
