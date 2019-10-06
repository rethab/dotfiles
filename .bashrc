#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

set -o vi

export HISTSIZE=100000
export HISTFILESIZE=100000
export HISTCONTROL=ignoredups:erasedups  
shopt -s histappend

# liquidprompt
export LP_PS1_POSTFIX="λ "
source /usr/bin/liquidprompt

export PATH="$PATH ~/.local/bin"

export NZ_CONF_FILE="/home/rethab/.application.conf"
export LOGGER_FILE="/home/rethab/.logback-info.xml"
export DUMP_DIR="/home/rethab/data"

source /usr/share/nvm/init-nvm.sh
source /home/rethab/dev/dotfiles/alias.sh
source /usr/share/z/z.sh

function rcr() { clear && rustc "${1}".rs && ./$1; }
