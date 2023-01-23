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
alias gw='./gradlew'

# Urxvt
alias bigfont="printf '\33]50;%s\007' \"xft:Terminus:pixelsize=20\""

# Git
alias gt='git'
alias g='git grep'
alias gp='git push'
alias gl='git status'
alias go='git checkout'

gob() {
  remote=$(git remote)
  git checkout -b "$1" --track "$remote/$1"
}

gsu() {
  remote=$(git remote)
  branch=$(git branch --show-current)
  git branch --set-upstream-to="$remote/$branch" "$branch"
}

alias gu='go main && git pull'
alias gub='gu && go -'
alias gdpr='git push && gh pr create --fill'

lgtm() {
  gh lgtmoon | gh pr review "$1" --approve -F -
}

gc() {
  git add . || return 1
  git commit -m "$*" || return 1
}

# Arch
alias Y='yaourt'
