#!/bin/bash
# Compose file drift detection (Jellyfin vs Plex variants)
# Returns warnings only - does not block commits

check_compose_drift() {
    local warnings=0
    local repo_root
    repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || repo_root="."

    local jellyfin_file="$repo_root/docker-compose.arr-stack.yml"
    local plex_file="$repo_root/docker-compose.plex-arr-stack.yml"

    # Skip if either file doesn't exist
    if [[ ! -f "$jellyfin_file" ]] || [[ ! -f "$plex_file" ]]; then
        echo "    SKIP: Both Jellyfin and Plex compose files needed for drift check"
        return 0
    fi

    # Count actual services (only entries under the services: block)
    local jellyfin_services plex_services
    jellyfin_services=$(awk '/^services:/{found=1; next} /^[a-z]/{found=0} found && /^  [a-z][a-z0-9_-]*:/{count++} END{print count+0}' "$jellyfin_file")
    plex_services=$(awk '/^services:/{found=1; next} /^[a-z]/{found=0} found && /^  [a-z][a-z0-9_-]*:/{count++} END{print count+0}' "$plex_file")

    if [[ "$jellyfin_services" != "$plex_services" ]]; then
        echo "    WARNING: Service count differs - Jellyfin: $jellyfin_services, Plex: $plex_services"
        ((warnings++))
    fi

    # Check for common services that should have matching configs
    local common_services=("gluetun" "qbittorrent" "sonarr" "radarr" "prowlarr" "pihole" "bazarr" "flaresolverr")

    for service in "${common_services[@]}"; do
        # Check if service exists in both
        local in_jellyfin=0 in_plex=0
        in_jellyfin=$(grep -c "^  $service:" "$jellyfin_file" 2>/dev/null) || in_jellyfin=0
        in_plex=$(grep -c "^  $service:" "$plex_file" 2>/dev/null) || in_plex=0

        if [[ "$in_jellyfin" -gt 0 && "$in_plex" -eq 0 ]]; then
            echo "    WARNING: Service '$service' exists in Jellyfin but not Plex"
            ((warnings++))
        elif [[ "$in_jellyfin" -eq 0 && "$in_plex" -gt 0 ]]; then
            echo "    WARNING: Service '$service' exists in Plex but not Jellyfin"
            ((warnings++))
        fi
    done

    # Check for environment variable naming consistency in gluetun
    local jellyfin_vpn_var plex_vpn_var
    jellyfin_vpn_var=$(grep -oE 'SERVER_COUNTRIES=\$\{[A-Z_]+' "$jellyfin_file" 2>/dev/null | head -1)
    plex_vpn_var=$(grep -oE 'SERVER_COUNTRIES=\$\{[A-Z_]+' "$plex_file" 2>/dev/null | head -1)

    if [[ -n "$jellyfin_vpn_var" && -n "$plex_vpn_var" && "$jellyfin_vpn_var" != "$plex_vpn_var" ]]; then
        echo "    WARNING: VPN country variable differs between files"
        echo "      Jellyfin: $jellyfin_vpn_var"
        echo "      Plex: $plex_vpn_var"
        ((warnings++))
    fi

    if [[ $warnings -eq 0 ]]; then
        echo "    OK: No significant drift detected"
    fi

    # Return 0 - warnings don't block commits
    return 0
}
