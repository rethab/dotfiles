TOOLS_DIR="$HOME/dev/tools"
PRIVATE_DIR="$HOME/dev/private"
CICD_DIR="$HOME/dev/cicd"

source $PRIVATE_DIR/dotfiles/alias.sh
source $CICD_DIR/cicd-scripts/alias.sh

export LP_PS1_POSTFIX="λ "
source $TOOLS_DIR/liquidprompt/liquidprompt

# fuzzy moving with z
eval "$(zoxide init zsh)"

# enable the fuck
eval $(thefuck --alias)


set -o vi
export EDITOR=vim

# Enable Ctrl-R for history
bindkey -v
bindkey ^R history-incremental-search-backward

# Other history settings (see https://unix.stackexchange.com/a/273863/39897)
export HISTSIZE=9999999
export HISTFILE="$HOME/.zsh_history"
setopt BANG_HIST                 # Treat the '!' character specially during expansion.
setopt EXTENDED_HISTORY          # Write the history file in the ":start:elapsed;command" format.
setopt INC_APPEND_HISTORY        # Write to the history file immediately, not when the shell exits.
setopt SHARE_HISTORY             # Share history between all sessions.
setopt HIST_EXPIRE_DUPS_FIRST    # Expire duplicate entries first when trimming history.
setopt HIST_IGNORE_DUPS          # Don't record an entry that was just recorded again.
setopt HIST_IGNORE_ALL_DUPS      # Delete old recorded entry if new entry is a duplicate.
setopt HIST_FIND_NO_DUPS         # Do not display a line previously found.
setopt HIST_IGNORE_SPACE         # Don't record an entry starting with a space.
setopt HIST_SAVE_NO_DUPS         # Don't write duplicate entries in the history file.
setopt HIST_REDUCE_BLANKS        # Remove superfluous blanks before recording entry.
setopt HIST_VERIFY               # Don't execute immediately upon history expansion.
