#!/bin/bash
# Hardcoded domain/hostname detection
# Reads domain from local .env and checks if it appears in staged files
# Also checks for NAS hostname (read from .claude/config.local.md)

check_hardcoded_domain() {
    local warnings=0
    local repo_root
    repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || repo_root="."

    local env_file="$repo_root/.env"
    local config_local="$repo_root/.claude/config.local.md"

    # Try to find NAS hostname from config.local.md
    local nas_hostname=""
    if [[ -f "$config_local" ]]; then
        nas_hostname=$(grep -oE '[a-zA-Z0-9_-]+\.local' "$config_local" 2>/dev/null | head -1 | sed 's/\.local$//')
    fi

    # Extract domain from .env (if exists)
    local domain=""
    if [[ -f "$env_file" ]]; then
        domain=$(grep -E '^DOMAIN=' "$env_file" 2>/dev/null | cut -d= -f2 | tr -d '"' | tr -d "'")
    fi

    # Get staged files (excluding .env which is gitignored anyway)
    local staged_files
    staged_files=$(git diff --cached --name-only --diff-filter=ACM 2>/dev/null | grep -v '^\.env$')

    if [[ -z "$staged_files" ]]; then
        return 0
    fi

    # Check for domain if configured
    if [[ -n "$domain" && "$domain" != "yourdomain.com" ]]; then
        local files_with_domain=""
        for file in $staged_files; do
            # Get staged content
            local content
            content=$(git show ":$file" 2>/dev/null) || continue

            # Skip binary files
            case "$file" in
                *.png|*.jpg|*.gif|*.ico|*.woff|*.ttf|*.svg) continue ;;
            esac

            # Check for domain (case insensitive)
            if echo "$content" | grep -qi "$domain" 2>/dev/null; then
                local count
                count=$(echo "$content" | grep -ci "$domain" 2>/dev/null || echo 0)
                files_with_domain+="      - $file ($count occurrences)"$'\n'
                ((warnings++))
            fi
        done

        if [[ -n "$files_with_domain" ]]; then
            echo "    WARNING: Your domain '$domain' is hardcoded in staged files:"
            echo "$files_with_domain"
            echo "    Note: Some files (like Traefik dynamic configs) can't use \${DOMAIN}"
            echo "          Review to ensure this is intentional."
        fi
    else
        echo "    SKIP: No custom domain configured"
    fi

    # Check for NAS hostname (BLOCKS - this should never be committed)
    if [[ -n "$nas_hostname" ]]; then
        local files_with_hostname=""
        local hostname_errors=0
        for file in $staged_files; do
            local content
            content=$(git show ":$file" 2>/dev/null) || continue

            # Skip binary files
            case "$file" in
                *.png|*.jpg|*.gif|*.ico|*.woff|*.ttf|*.svg) continue ;;
            esac

            # Check for hostname (case insensitive)
            if echo "$content" | grep -qi "$nas_hostname" 2>/dev/null; then
                local count
                count=$(echo "$content" | grep -ci "$nas_hostname" 2>/dev/null || echo 0)
                files_with_hostname+="      - $file ($count occurrences)"$'\n'
                ((hostname_errors++))
            fi
        done

        if [[ -n "$files_with_hostname" ]]; then
            echo "    ERROR: NAS hostname '$nas_hostname' found in staged files:"
            echo "$files_with_hostname"
            echo "    This is private info and should not be committed."
            return 1
        fi
    fi

    return 0
}
