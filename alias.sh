#!/bin/bash

# Linux
alias ls='ls -G'
alias cp='cp -i'
alias mv='mv -i'
alias ln='ln -i'
alias dmesg='dmesg --human'
alias :q='exit'
alias grep='grep --color=always'
alias grop='grep --color=never'
alias sudo='sudo -E'
alias csvawk='awk -v FPAT="([^,]*)|(\"([^\"]|\"\")+\")"'
alias plainvim='vim -u NONE'

alias weather='curl wttr.in'

alias k=kubectl

_claude_find_parent_claude_md() {
  local dir="$PWD"
  while [ "$dir" != "$HOME" ] && [ "$dir" != "/" ]; do
    dir="$(dirname "$dir")"
    if [ -f "$dir/.claude/CLAUDE.md" ]; then
      echo "$dir"
      return
    fi
  done
}

_claude_find_parent_settings() {
  local dir="$PWD"
  while [ "$dir" != "$HOME" ] && [ "$dir" != "/" ]; do
    dir="$(dirname "$dir")"
    if [ -f "$dir/.claude/settings.json" ]; then
      echo "$dir/.claude/settings.json"
      return
    fi
  done
}

_claude_discover_plugins() {
  local dir="$PWD"
  local -A seen
  while [ "$dir" != "$HOME" ] && [ "$dir" != "/" ]; do
    dir="$(dirname "$dir")"
    if [ -d "$dir/.claude/plugins" ]; then
      for p in "$dir"/.claude/plugins/*/; do
        local name="$(basename "$p")"
        if [ -d "${p}.claude-plugin" ] && [ -z "${seen[$name]}" ]; then
          seen[$name]=1
          echo "$p"
        fi
      done
    fi
  done
}

_claude_find_parent_mcp_config() {
  local parent="$(dirname "$PWD")"
  if [ "$parent" != "$HOME" ] && [ "$parent" != "/" ] && [ -f "$parent/.mcp.json" ]; then
    echo "$parent/.mcp.json"
  fi
}

c() {
  # `agents` is the only subcommand we pass through; everything else that
  # doesn't start with `-` is treated as a prompt.
  if [ "$1" != "agents" ] && [ $# -gt 0 ] && [ "${1#-}" = "$1" ]; then
    set -- -- "$*"
  fi
  local add_dir="$(_claude_find_parent_claude_md)"
  local settings_file="$(_claude_find_parent_settings)"
  local mcp_config="$(_claude_find_parent_mcp_config)"
  local plugin_args=()
  while IFS= read -r p; do
    [ -n "$p" ] && plugin_args+=(--plugin-dir "$p")
  done < <(_claude_discover_plugins)
  local settings_args=()
  [ -n "$settings_file" ] && settings_args=(--settings "$settings_file")
  local mcp_args=()
  [ -n "$mcp_config" ] && mcp_args=(--mcp-config "$mcp_config")
  local model_args=()
  local has_model=0
  local arg
  for arg in "$@"; do
    case "$arg" in
      --model|--model=*) has_model=1; break ;;
    esac
  done
  [ "$has_model" -eq 0 ] && model_args=(--model default)
  export CLAUDE_CODE_NO_FLICKER=1
  if [ -n "$add_dir" ]; then
    CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD=1 claude --add-dir "$add_dir" "${plugin_args[@]}" "${settings_args[@]}" "${mcp_args[@]}" "${model_args[@]}" "$@"
  else
    claude "${plugin_args[@]}" "${settings_args[@]}" "${mcp_args[@]}" "${model_args[@]}" "$@"
  fi
}

alias gw='./gradlew'

mw() {
  if [ ! -f "pom.xml" ]; then
    echo "Error: No pom.xml found in current directory" >&2
    return 1
  fi
  if [ -f "./mvnw" ]; then
    ./mvnw "$@"
  else
    mvn "$@"
  fi
}

# Git
alias g='git grep'
alias gp='git push'
alias gl='git status'
alias goto='git checkout'

gob() {
  git checkout -b "$1"
}

gsu() {
  remote=$(git remote)
  branch=$(git branch --show-current)
  git branch --set-upstream-to="$remote/$branch" "$branch"
}

~/dev/private/dotfiles/sysdeps.sh check 2>/dev/null || true
alias syslist='~/dev/private/dotfiles/sysdeps.sh list'
alias sysupgrade='~/dev/private/dotfiles/sysdeps.sh upgrade'

alias gu='goto main && git pull'
alias gub='gu && goto -'
gdpr() {
  local branch
  branch=$(git symbolic-ref --short HEAD 2>/dev/null) || {
    echo "gdpr: not on a branch" >&2
    return 1
  }
  if [ "$branch" = "main" ] || [ "$branch" = "master" ]; then
    echo "gdpr: refusing to run on '$branch' — create a feature branch first" >&2
    return 1
  fi
  git push --no-verify && gh pr create --fill "$@"
}
alias ghw='gh pr view --web'

gc() {
  git add . || return 1
  git commit -m "$*" || return 1
}

traceparent() {
  printf '00-%s-%s-01\n' "$(openssl rand -hex 16)" "$(openssl rand -hex 8)"
}

curlt() {
  local tp
  tp="$(traceparent)"
  printf 'traceid: %s\n' "$(printf '%s' "$tp" | cut -d- -f2)" >&2
  curl -H "traceparent: $tp" "$@"
}
