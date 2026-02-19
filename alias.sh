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

c() {
  # If first arg doesn't start with -, join all args as a single prompt
  if [ $# -gt 0 ] && [ "${1#-}" = "$1" ]; then
    set -- -- "$*"
  fi
  local add_dir="$(_claude_find_parent_claude_md)"
  local plugin_args=()
  while IFS= read -r p; do
    [ -n "$p" ] && plugin_args+=(--plugin-dir "$p")
  done < <(_claude_discover_plugins)
  if [ -n "$add_dir" ]; then
    CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD=1 claude --add-dir "$add_dir" "${plugin_args[@]}" "$@"
  else
    claude "${plugin_args[@]}" "$@"
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
alias gdpr='git push && gh pr create --fill'
alias ghw='gh pr view --web'

gc() {
  git add . || return 1
  git commit -m "$*" || return 1
}
