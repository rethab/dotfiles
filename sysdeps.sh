#!/bin/zsh -l

# System Dependencies Manager
# Lists installed packages across all package managers with the reason they
# were installed (from ~/.sysdeps-reasons), and upgrades all of them.
#
# Adding a package manager: write a list_* and/or upgrade_* function and
# register it in LIST_STEPS / UPGRADE_STEPS.

REASONS_FILE="$HOME/.sysdeps-reasons"
TIMESTAMP_FILE="$HOME/.sysdeps-last-upgrade"
MAX_AGE_DAYS=7
SDKMAN_INIT="$HOME/.sdkman/bin/sdkman-init.sh"
NVM_INIT="$HOME/.nvm/nvm.sh"

RED=$'\e[31m'
GREEN=$'\e[32m'
YELLOW=$'\e[33m'
RESET=$'\e[0m'

set -e

typeset -A REASONS
FAILED_STEPS=()

LIST_STEPS=(
    'Brew Regular'         list_brew
    'Brew Casks'           list_brew_casks
    'Brew Trusted'         list_brew_trusted
    'Mac App Store'        list_mas
    'NPM'                  list_npm
    'gh Extensions'        list_gh_extensions
    'Custom'               list_custom
    'Claude Code Plugins'  list_claude_plugins
)

UPGRADE_STEPS=(
    'Brew'                 upgrade_brew
    'Mac App Store'        upgrade_mas
    'sdk'                  upgrade_sdkman
    'Java'                 upgrade_java
    'nvm'                  upgrade_node
    'NPM'                  upgrade_npm
    'gh Extensions'        upgrade_gh_extensions
    'Claude Code'          upgrade_claude
    'Claude Code Plugins'  upgrade_claude_plugins
)

# --- Helpers ----------------------------------------------------------------

has() {
    command -v "$1" >/dev/null 2>&1
}

# Prints a skip notice for the first missing command, so steps can `require x || return 0`
require() {
    local cmd
    for cmd in "$@"; do
        if ! has "$cmd"; then
            echo "  $cmd not installed - skipping"
            return 1
        fi
    done
}

ensure_reasons_file() {
    [[ -f "$REASONS_FILE" ]] && return 0

    echo "Reasons file not found at $REASONS_FILE"
    if read -q "?Would you like to create it? (y/N): "; then
        echo
        cat > "$REASONS_FILE" << 'EOF'
# System dependencies reasons file
# Format: tool:package_name:reason
# Examples:
# brew:git:Version control system for development
# brew-cask:docker:Container development and deployment
# npm:typescript:Static typing for JavaScript projects
# gh-ext:github/gh-stack:Stacked PRs from the gh cli
# mas:Keynote:Presentation software for work presentations
# custom:app-name:Manually installed applications not managed by package managers
EOF
        echo "Created $REASONS_FILE"
    else
        echo
        echo "Continuing without reasons file..."
    fi
}

load_reasons() {
    [[ -f "$REASONS_FILE" ]] || return 0

    local line tool rest
    while IFS= read -r line; do
        [[ "$line" == \#* || "$line" != *:*:* ]] && continue
        tool=${line%%:*}
        rest=${line#*:}
        REASONS+=("$tool:${rest%%:*}" "${rest#*:}")
    done < "$REASONS_FILE"
}

# Reads package names from stdin, one per line
show_reasons() {
    local tool="$1" package reason found=false

    while IFS= read -r package; do
        if [[ -n "$package" ]]; then
            found=true
            reason=${REASONS[$tool:$package]}
            if [[ -n "$reason" ]]; then
                printf "  %-30s - %s\n" "$package" "$reason"
            else
                printf "  %-30s - %sWARNING: No reason specified%s\n" "$package" "$YELLOW" "$RESET"
            fi
        fi
    done

    if [[ "$found" == false ]]; then
        echo "  None"
    fi
}

# Takes alternating title/function pairs and records failed steps in FAILED_STEPS
run_steps() {
    local title fn first=true
    local failed_before=${#FAILED_STEPS}

    for title fn in "$@"; do
        [[ "$first" == true ]] || echo
        first=false
        echo "$title:"
        if ! "$fn"; then
            echo "  ${RED}ERROR: $title failed${RESET}"
            FAILED_STEPS+=("$title")
        fi
    done

    (( ${#FAILED_STEPS} == failed_before ))
}

# --- list -------------------------------------------------------------------

list_brew() {
    brew ls --installed-on-request | show_reasons brew
}

list_brew_casks() {
    brew ls --casks -1 | show_reasons brew-cask
}

list_brew_trusted() {
    require jq || return 0
    brew trust --json v1 2>/dev/null \
        | jq -r '[.taps[], .formulae[], .casks[], .commands[]] | .[]' \
        | show_reasons brew-trust
}

list_mas() {
    require mas || return 0
    # mas list prints "ID   Name   (Version)"
    mas list 2>/dev/null \
        | sed -E 's/^[[:space:]]*[0-9]+[[:space:]]+([^(]+)\([^)]+\)$/\1/; s/[[:space:]]+$//' \
        | show_reasons mas
}

list_npm() {
    require npm || return 0
    # Skip the prefix dir and the packages bundled with Node
    npm ls --global --parseable --depth=0 2>/dev/null \
        | sed 's|.*/||' \
        | grep -vxE 'lib|npm|corepack' \
        | show_reasons npm
}

list_gh_extensions() {
    require gh || return 0

    local ext_list
    ext_list=$(gh extension list) || return 1

    # Local extensions have no repo, so fall back to the extension name
    awk -F'\t' '{ n = $1; sub(/^gh /, "", n); print ($2 != "" ? $2 : n) }' <<< "$ext_list" \
        | show_reasons gh-ext
}

list_custom() {
    require claude || return 0
    echo claude-code | show_reasons custom
}

list_claude_plugins() {
    require claude jq || return 0
    claude plugin list --json 2>/dev/null | jq -r '.[].id' | show_reasons claude-plugin
}

# --- upgrade ----------------------------------------------------------------
# Steps run as `if` conditions, where set -e is suspended, so they must return
# non-zero themselves on failure.

upgrade_brew() {
    local untrusted
    untrusted=$(brew tap-info --json --installed 2>/dev/null \
        | jq -r '.[] | select(.official == false and .trusted == false) | .name')

    if [[ -n "$untrusted" ]]; then
        echo "  ${RED}Untrusted taps detected:${RESET}"
        echo "$untrusted" | sed 's/^/    /'
        echo "  Trust them with:  brew trust --tap <user>/<tap>"
        echo "  Or remove with:   brew untap <user>/<tap>"
        return 1
    fi

    brew update && brew upgrade --no-ask && brew upgrade --cask --greedy --no-ask
}

upgrade_mas() {
    require mas || return 0
    mas upgrade
}

upgrade_sdkman() {
    require sdk || return 0
    sdk update && sdk selfupdate
}

# Moves to the latest patch release of the current major version and vendor
upgrade_java() {
    require sdk || return 0

    local current major vendor latest
    current=$(sdk current java 2>/dev/null | grep -oE '[0-9][0-9.]*-[a-z]+$')
    if [[ -z "$current" ]]; then
        echo "  No Java version detected - skipping"
        return 0
    fi
    major=${current%%[.-]*}
    vendor=${current##*-}
    echo "  Current: $current (major=$major, vendor=$vendor)"

    latest=$(sdk list java 2>/dev/null \
        | sed 's/\x1b\[[0-9;]*m//g' \
        | grep -oE "${major}\.[0-9]+\.[0-9]+(\.[0-9]+)?-${vendor}" \
        | sort -V \
        | tail -1)

    # Also guards against downgrading when the current version is no longer listed
    if [[ -z "$latest" || "$(printf '%s\n' "$current" "$latest" | sort -V | tail -1)" == "$current" ]]; then
        echo "  Java is up to date"
        return 0
    fi

    echo "  Upgrading Java to $latest..."
    sdk install java "$latest" && sdk default java "$latest"
}

# Moves to the latest release of the current major version
upgrade_node() {
    require nvm node || return 0

    local current major latest
    current=$(node --version)
    major=${${current#v}%%.*}
    latest=$(nvm version-remote "$major") || return 1
    [[ "$latest" == v* ]] || return 1

    if [[ "$latest" == "$current" ]]; then
        echo "  Node.js $current is up to date"
        return 0
    fi

    echo "  Upgrading Node.js $current to $latest..."
    # Without this, global npm packages stay behind on the old version
    nvm install "$latest" --reinstall-packages-from="$current"
}

upgrade_npm() {
    require npm || return 0
    npm update -g
}

upgrade_gh_extensions() {
    require gh || return 0
    gh extension upgrade --all
}

upgrade_claude() {
    require claude || return 0
    claude update
}

upgrade_claude_plugins() {
    require claude jq || return 0

    local plugin_json plugin_id plugin_scope failed=false
    plugin_json=$(claude plugin list --json 2>/dev/null)
    if [[ -z "$plugin_json" ]] || ! jq -e . <<< "$plugin_json" >/dev/null 2>&1; then
        echo "  Could not read plugin list"
        return 1
    fi

    echo "  Updating $(jq '[.[] | select(.enabled)] | length' <<< "$plugin_json") enabled plugin(s)..."
    while IFS=$'\t' read -r plugin_id plugin_scope; do
        [[ -z "$plugin_id" ]] && continue
        echo "  Updating $plugin_id ($plugin_scope)..."
        if ! claude plugin update "$plugin_id" --scope "$plugin_scope"; then
            echo "  ERROR: Plugin update failed for $plugin_id"
            failed=true
        fi
    done < <(jq -r '.[] | select(.enabled) | "\(.id)\t\(.scope)"' <<< "$plugin_json")

    [[ "$failed" == false ]]
}

# --- Commands ---------------------------------------------------------------

cmd_list() {
    ensure_reasons_file
    load_reasons
    run_steps "${LIST_STEPS[@]}" || true
}

cmd_upgrade() {
    if run_steps "${UPGRADE_STEPS[@]}"; then
        date +%s > "$TIMESTAMP_FILE"
        echo
        echo "${GREEN}✓ All upgrades completed successfully!${RESET}"
        echo "${GREEN}  Timestamp saved to $TIMESTAMP_FILE${RESET}"
    else
        echo
        echo "${RED}✗ Failed: ${(j:, :)FAILED_STEPS} - timestamp not updated${RESET}"
        echo "${RED}  Fix the errors above and run upgrade again${RESET}"
        return 1
    fi
}

cmd_check() {
    local last_upgrade
    last_upgrade=$(cat "$TIMESTAMP_FILE" 2>/dev/null) || true

    if [[ "$last_upgrade" != <-> ]]; then
        echo "${RED}┌─────────────────────────────────────────────────────────────┐${RESET}"
        echo "${RED}│ ⚠️  WARNING: System dependencies have never been upgraded!  │${RESET}"
        echo "${RED}│     Run 'sysupgrade' to upgrade all dependencies.           │${RESET}"
        echo "${RED}└─────────────────────────────────────────────────────────────┘${RESET}"
        return 1
    fi

    local days_old=$(( ($(date +%s) - last_upgrade) / 86400 ))
    if (( days_old >= MAX_AGE_DAYS )); then
        local last_upgrade_date=$(date -r "$last_upgrade" "+%Y-%m-%d %H:%M:%S")
        echo "${YELLOW}┌─────────────────────────────────────────────────────────────┐${RESET}"
        printf "%s│ ⚠️  WARNING: Dependencies are %-30s│%s\n" "$YELLOW" "$days_old days old!" "$RESET"
        printf "%s│     Last upgrade: %-42s│%s\n" "$YELLOW" "$last_upgrade_date" "$RESET"
        echo "${YELLOW}│     Consider running 'sysupgrade' to update.                │${RESET}"
        echo "${YELLOW}└─────────────────────────────────────────────────────────────┘${RESET}"
        return 1
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

case "$1" in
    list)
        cmd_list
        ;;
    upgrade)
        # sdk and nvm are shell functions that only exist once their init scripts are sourced
        if ! has sdk && [[ -s "$SDKMAN_INIT" ]]; then
            source "$SDKMAN_INIT"
        fi
        if ! has nvm && [[ -s "$NVM_INIT" ]]; then
            source "$NVM_INIT"
        fi
        cmd_upgrade
        echo
        cmd_list
        ;;
    check)
        cmd_check
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
