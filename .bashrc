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
export PATH="$PATH:/home/rethab/.local/share/coursier/bin"

source $DEV_DIR/dotfiles/alias.sh
source $DEV_DIR/z/z.sh

function rcr() { clear && rustc "${1}".rs && ./$1; }

# intellichain auto completion for run.sh
export INTELLICHAIN_RUN_WORDLIST="db db psql app app-azure-dev app-azure-acc be-ssh-dev be-ssh-dev-tunnel be-ssh-acc be-ssh-acc-tunnel fe-ssh-dev fe-ssh-acc owlin-import-local owlin-import-dev owlin-import-acc supplier-import-local user-import-local supplier-import-dev user-import-dev supplier-import-acc user-import-acc export-news-events"
complete -W "$INTELLICHAIN_RUN_WORDLIST" run.sh
