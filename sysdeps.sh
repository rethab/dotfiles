#!/bin/bash

# System Dependencies Manager
# Lists installed packages from brew/npm with reasons from ~/.sysdeps-reasons
# Upgrades all package managers (brew, sdk, npm)

REASONS_FILE="$HOME/.sysdeps-reasons"

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
    echo 'Brew:'
    brew update
    brew upgrade
    brew upgrade --cask

    echo
    echo 'sdk:'
    # SDK commands (check if available)
    if command -v sdk >/dev/null 2>&1; then
        sdk update # update version information
        sdk selfupdate # update sdk itself
        sdk upgrade # upgrade tools
    elif [[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]]; then
        # Source SDKMAN if available
        source "$HOME/.sdkman/bin/sdkman-init.sh"
        sdk update
        sdk selfupdate
        sdk upgrade
    else
        echo "SDK command not found - skipping SDK updates"
    fi

    echo
    echo 'NPM:'
    npm update -g
}

case "$1" in
    list)
        cmd_list
        ;;
    upgrade)
        cmd_upgrade
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
