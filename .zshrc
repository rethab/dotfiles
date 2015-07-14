# Path to your oh-my-zsh configuration.
ZSH=$HOME/.oh-my-zsh

# systemd: creates alias sc-xx=systemctl xx
plugin=(archlinux cabal colored-man git systemd vagrant vi-mode)

source $ZSH/oh-my-zsh.sh

export LP_PS1_POSTFIX="λ "
source /usr/bin/liquidprompt

# fix old GREP_OPTIONS in oh-my-zsh/lib/grep.zsh
alias grep="/usr/bin/grep $GREP_OPTIONS"
unset GREP_OPTIONS

set -o vi
export EDITOR=vim

# Enable Ctrl-R for history
bindkey -v
bindkey ^R history-incremental-search-backward

path+=('/home/rethab/.cabal/bin')
export PATH

# Linux
alias ls='ls --color=auto'
alias cp='cp -i'
alias mv='mv -i'
alias ln='ln -i'
alias dmesg='dmesg --human'
alias :q='exit'
alias grep='grep --color=always'

alias unlockssh='eval $(ssh-agent) && ssh-add'

# Arch
alias Y='yaourt'

# Git
alias lala='git status'

# https://github.com/zsh-users/zsh-syntax-highlighting
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# https://github.com/rupa/z
export _Z_DATA=~/.z/data
source ~/mirror/z/z.sh

# arch linux java switching
source /etc/profile.d/jre.sh
