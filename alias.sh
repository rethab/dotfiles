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

c() {
  local dir="$PWD"
  local home="$HOME"
  # If first arg doesn't start with -, join all args as a single prompt
  local prompt=""
  if [ $# -gt 0 ] && [ "${1#-}" = "$1" ]; then
    prompt="$*"
    set -- -- "$prompt"
  fi
  while [ "$dir" != "$home" ] && [ "$dir" != "/" ]; do
    dir="$(dirname "$dir")"
    if [ -f "$dir/.claude/CLAUDE.md" ]; then
      CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD=1 claude --add-dir "$dir" "$@"
      return
    fi
  done
  claude "$@"
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
