# Path to your oh-my-zsh configuration.
ZSH=$HOME/.oh-my-zsh

# systemd: creates alias sc-xx=systemctl xx
plugin=(archlinux colored-man git systemd vi-mode heroku sbt)

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
path+=('/opt/mongodb/bin')
export PATH

# Linux
alias ls='ls --color=auto'
alias cp='cp -i'
alias mv='mv -i'
alias ln='ln -i'
alias dmesg='dmesg --human'
alias :q='exit'
alias grep='grep --color=always'
alias sudo='sudo -E'

# Git
alias g='git grep'
alias gl='git lala2'
alias gm='git cam2'
alias go='git co2'
alias gp='git co2 -'

alias lala='echo "use gl"'

alias unlockssh='eval $(ssh-agent) && ssh-add'

# Arch
alias Y='yaourt'


# https://github.com/zsh-users/zsh-syntax-highlighting
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# https://github.com/rupa/z
export _Z_DATA=~/.z/data
source ~/mirror/z/z.sh

# arch linux java switching
source /etc/profile.d/jre.sh


### Aliases for Nezasa dev
alias playdev='activator -Dconfig.file=conf/application-dev.${USER}.conf'
alias playdevdebug='activator -jvm-debug 9999 -Dconfig.file=conf/application-dev.${USER}.conf'
alias playdevworker='activator -Dconfig.file=conf/application-dev.${USER}.conf -Dapplication.global=Worker'

PROJECT_PATH="~/secure/dev/platform/"
alias mongo_dev="${PROJECT_PATH}/etc/dev/alias/mongo_dev.sh"
alias mongo_dev_clone="${PROJECT_PATH}/etc/release/cloneDatabase/cloneDatabase.sh --local"
alias mongo_dev_dump="${PROJECT_PATH}/etc/dev/alias/mongo_dev_dump.sh"
alias mongo_dev_restore="${PROJECT_PATH}/etc/dev/alias/mongo_dev_restore.sh"
alias sbt='sbt -mem 2496'
