#!/bin/bash
# Check Uptime Kuma monitors match expected services
# Returns warnings only - does not block commits

check_uptime_monitors() {
    local repo_root
    repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || repo_root="."

    # Expected monitors (services that should be monitored)
    local expected=(
        "Bazarr"
        "duc"
        "FlareSolverr"
        "Jellyfin"
        "Jellyseerr"
        "Pi-hole"
        "Prowlarr"
        "qBittorrent"
        "qbit-scheduler"
        "Radarr"
        "Sonarr"
        "Traefik"
        "WireGuard"
    )

    # Try to get NAS host from config.local.md or use default
    local nas_host="yournas.local"
    local nas_user="admin"

    # Check if NAS is reachable
    if ! timeout 2 ping -c 1 "$nas_host" &>/dev/null; then
        echo "    SKIP: NAS not reachable"
        return 0
    fi

    # Get actual monitors from Uptime Kuma
    # Use timeout to prevent hanging if SSH or docker exec stalls
    local actual
    actual=$(timeout 15 sshpass -p '***REDACTED***' ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 "$nas_user@$nas_host" \
        "docker exec uptime-kuma sqlite3 /app/data/kuma.db \"SELECT name FROM monitor ORDER BY name;\"" 2>/dev/null)

    if [[ -z "$actual" ]]; then
        echo "    SKIP: Could not query Uptime Kuma (SSH failed or timed out)"
        return 0
    fi

    local warnings=0

    # Check for missing monitors
    for service in "${expected[@]}"; do
        local service_lower=$(echo "$service" | tr '[:upper:]' '[:lower:]')
        local found=0
        while IFS= read -r monitor; do
            local monitor_lower=$(echo "$monitor" | tr '[:upper:]' '[:lower:]')
            if [[ "$monitor_lower" == "$service_lower" ]]; then
                found=1
                break
            fi
        done <<< "$actual"
        if [[ $found -eq 0 ]]; then
            echo "    WARNING: Missing monitor for '$service'"
            ((warnings++))
        fi
    done

    # Check for unexpected monitors (excluding known extras like Home Assistant, Reolink)
    local known_extras=("Home Assistant" "Reolink NVR")
    while IFS= read -r monitor; do
        [[ -z "$monitor" ]] && continue
        local found=0
        local monitor_lower=$(echo "$monitor" | tr '[:upper:]' '[:lower:]')
        for service in "${expected[@]}" "${known_extras[@]}"; do
            local service_lower=$(echo "$service" | tr '[:upper:]' '[:lower:]')
            if [[ "$monitor_lower" == "$service_lower" ]]; then
                found=1
                break
            fi
        done
        if [[ $found -eq 0 ]]; then
            echo "    WARNING: Unknown monitor '$monitor' (removed service?)"
            ((warnings++))
        fi
    done <<< "$actual"

    if [[ $warnings -eq 0 ]]; then
        echo "    OK: Monitors match expected services"
    fi

    return 0
}
