#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

set -o vi

DEV_DIR=/home/rethab/dev

export HISTSIZE=100000
export HISTFILESIZE=100000
export HISTCONTROL=ignoredups:erasedups  
shopt -s histappend

# liquidprompt
export LP_PS1_POSTFIX="λ "
export LP_ENABLE_RUNTIME=0
source $DEV_DIR/liquidprompt/liquidprompt

export PATH="$PATH:/snap/bin"

source $DEV_DIR/dotfiles/alias.sh
source $DEV_DIR/z/z.sh

function rcr() { clear && rustc "${1}".rs && ./$1; }
