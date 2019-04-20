# Path to your oh-my-zsh configuration.
ZSH=/usr/share/oh-my-zsh/

# systemd: creates alias sc-xx=systemctl xx
plugins=(colored-man zsh-nvm aws git)

source $ZSH/oh-my-zsh.sh

source /home/rethab/dev/dotfiles/alias.sh

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

path+=('/home/rethab/.cabal/bin')
path+=('/usr/local/heroku/bin')
path+=('/home/rethab/.local/bin')
export PATH

export TRANSPORTER_EXEC=~/bin/transporter-0.3.0-linux-amd64



# https://github.com/rupa/z
export _Z_DATA=~/.z/data
source /usr/share/z/z.sh

# arch linux java switching
source /etc/profile.d/jre.sh

source /usr/share/nvm/init-nvm.sh
