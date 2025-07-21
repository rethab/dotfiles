#!/bin/bash

# System Dependencies Manager
# Lists installed packages from brew/npm/mas with reasons from ~/.sysdeps-reasons
# Upgrades all package managers (brew, sdk, npm, mas)

REASONS_FILE="$HOME/.sysdeps-reasons"
TIMESTAMP_FILE="$HOME/.sysdeps-last-upgrade"

ensure_reasons_file() {
    if [[ ! -f "$REASONS_FILE" ]]; then
        echo "Reasons file not found at $REASONS_FILE"
        read -p "Would you like to create it? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            cat > "$REASONS_FILE" << 'EOF'
# System dependencies reasons file
# Format: tool:package_name:reason
# Examples:
# brew:git:Version control system for development
# brew-cask:docker:Container development and deployment
# npm:typescript:Static typing for JavaScript projects
# mas:Keynote:Presentation software for work presentations
EOF
            echo "Created $REASONS_FILE"
        else
            echo "Continuing without reasons file..."
        fi
    fi
}

get_reason() {
    local tool="$1"
    local package="$2"
    
    if [[ ! -f "$REASONS_FILE" ]]; then
        return 1
    fi
    
    grep "^$tool:$package:" "$REASONS_FILE" 2>/dev/null | cut -d: -f3-
}

check_upgrade_freshness() {
    if [[ ! -f "$TIMESTAMP_FILE" ]]; then
        echo -e "\033[31m┌─────────────────────────────────────────────────────────────┐\033[0m"
        echo -e "\033[31m│ ⚠️  WARNING: System dependencies have never been upgraded!  │\033[0m"
        echo -e "\033[31m│     Run 'sysupgrade' to upgrade all dependencies.           │\033[0m"
        echo -e "\033[31m└─────────────────────────────────────────────────────────────┘\033[0m"
        return 1
    fi
    
    local last_upgrade=$(cat "$TIMESTAMP_FILE" 2>/dev/null)
    local current_time=$(date +%s)
    local week_in_seconds=$((7 * 24 * 60 * 60))
    local time_diff=$((current_time - last_upgrade))
    
    if [[ $time_diff -gt $week_in_seconds ]]; then
        local days_old=$((time_diff / (24 * 60 * 60)))
        local last_upgrade_date=$(date -r "$last_upgrade" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "unknown")
        echo -e "\033[33m┌─────────────────────────────────────────────────────────────┐\033[0m"
        echo -e "\033[33m│ ⚠️  WARNING: Dependencies are $days_old days old!                  │\033[0m"
        echo -e "\033[33m│     Last upgrade: $last_upgrade_date                       │\033[0m"
        echo -e "\033[33m│     Consider running 'sysupgrade' to update.                │\033[0m"
        echo -e "\033[33m└─────────────────────────────────────────────────────────────┘\033[0m"
        return 1
    fi
    
    return 0
}

show_package_with_reason() {
    local tool="$1"
    local package="$2"
    local reason
    
    reason=$(get_reason "$tool" "$package")
    if [[ -n "$reason" ]]; then
        printf "  %-30s - %s\n" "$package" "$reason"
    else
        printf "  %-30s - \033[33mWARNING: No reason specified\033[0m\n" "$package"
    fi
}

usage() {
    cat << EOF
Usage: $0 <command>

Commands:
    list      List installed software packages with reasons
    upgrade   Upgrade all installed packages
    check     Check if dependencies need upgrading (shows warnings)
    help      Show this help message

Examples:
    $0 list
    $0 upgrade
EOF
}

cmd_list() {
    ensure_reasons_file
    
    echo 'Brew Regular:'
    while IFS= read -r package; do
        show_package_with_reason "brew" "$package"
    done < <(brew ls --installed-on-request)

    echo 
    echo 'Brew Casks:'
    while IFS= read -r package; do
        show_package_with_reason "brew-cask" "$package"
    done < <(brew ls --casks -1)

    echo 
    echo 'Mac App Store:'
    if command -v mas >/dev/null 2>&1; then
        mas list 2>/dev/null | while IFS= read -r line; do
            if [[ -n "$line" ]]; then
                # Parse mas list output: "ID   Name   (Version)"
                app_name=$(echo "$line" | sed -E 's/^[0-9]+[[:space:]]+([^(]+)[[:space:]]*\([^)]+\)$/\1/' | sed 's/[[:space:]]*$//')
                if [[ -n "$app_name" ]]; then
                    show_package_with_reason "mas" "$app_name"
                fi
            fi
        done
    else
        echo "  mas not installed - skipping Mac App Store apps"
    fi

    echo 
    echo 'NPM:'
    npm ls --global --parseable --depth=0 2>/dev/null | while IFS= read -r path; do
        if [[ -n "$path" ]]; then
            package=$(basename "$path")
            # Skip npm itself and empty lines
            if [[ "$package" != "npm" && "$package" != "lib" ]]; then
                show_package_with_reason "npm" "$package"
            fi
        fi
    done
}

cmd_upgrade() {
    local upgrade_failed=false
    
    echo 'Brew:'
    if ! (brew update && brew upgrade && brew upgrade --cask); then
        echo "ERROR: Brew upgrade failed"
        upgrade_failed=true
    fi

    echo
    echo 'Mac App Store:'
    if command -v mas >/dev/null 2>&1; then
        if ! mas upgrade; then
            echo "ERROR: Mac App Store upgrade failed"
            upgrade_failed=true
        fi
    else
        echo "mas not installed - skipping Mac App Store updates"
    fi

    echo
    echo 'sdk:'
    # SDK commands (check if available)
    if command -v sdk >/dev/null 2>&1; then
        if ! (sdk update && sdk selfupdate && sdk upgrade); then
            echo "ERROR: SDK upgrade failed"
            upgrade_failed=true
        fi
    elif [[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]]; then
        # Source SDKMAN if available
        source "$HOME/.sdkman/bin/sdkman-init.sh"
        if ! (sdk update && sdk selfupdate && sdk upgrade); then
            echo "ERROR: SDK upgrade failed"
            upgrade_failed=true
        fi
    else
        echo "SDK command not found - skipping SDK updates"
    fi

    echo
    echo 'NPM:'
    if ! npm update -g; then
        echo "ERROR: NPM upgrade failed"
        upgrade_failed=true
    fi
    
    # Only update timestamp if all upgrades succeeded
    if [[ "$upgrade_failed" == "false" ]]; then
        date +%s > "$TIMESTAMP_FILE"
        echo
        echo -e "\033[32m✓ All upgrades completed successfully!\033[0m"
        echo -e "\033[32m  Timestamp saved to $TIMESTAMP_FILE\033[0m"
    else
        echo
        echo -e "\033[31m✗ Some upgrades failed - timestamp not updated\033[0m"
        echo -e "\033[31m  Fix the errors above and run upgrade again\033[0m"
        exit 1
    fi
}

case "$1" in
    list)
        cmd_list
        ;;
    upgrade)
        cmd_upgrade
        ;;
    check)
        check_upgrade_freshness
        ;;
    help|--help|-h)
        usage
        ;;
    "")
        echo "Error: No command specified"
        usage
        exit 1
        ;;
    *)
        echo "Error: Unknown command '$1'"
        usage
        exit 1
        ;;
esac
