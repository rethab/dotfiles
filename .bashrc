#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
PS1='[\u@\h \W]\$ '

export PATH="$PATH ~/.local/bin"

export NZ_CONF_FILE="/home/rethab/.application.conf"
export DUMP_DIR="/home/rethab/data"

set -o vi
alias Y=yaourt
alias gl="git status"
alias playdev="make playdev"
source /usr/share/nvm/init-nvm.sh

export LP_PS1_POSTFIX="λ "
source /usr/bin/liquidprompt

[[ -r "/usr/share/z/z.sh" ]] && source /usr/share/z/z.sh
