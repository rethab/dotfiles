# Path to your oh-my-zsh configuration.
ZSH=/usr/share/oh-my-zsh/

export NVM_AUTO_USE=true

# systemd: creates alias sc-xx=systemctl xx
plugins=(colored-man zsh-nvm aws git)

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
export PATH

export TRANSPORTER_EXEC=~/bin/transporter-0.3.0-linux-amd64

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
alias gu='go develop && git pull && go -'

alias lala='echo "use gl"'

alias unlockssh='eval $(ssh-agent) && ssh-add'

# Arch
alias Y='yaourt'


# https://github.com/rupa/z
export _Z_DATA=~/.z/data
source /usr/share/z/z.sh

# arch linux java switching
source /etc/profile.d/jre.sh


### Aliases for Nezasa dev
alias playdev='activator -mem 2496 -jvm-debug 9999 -Dconfig.file=/home/rethab/.application-dev.rethab.conf -Dhttps.port=9443 -Dhttps.keyStore=etc/dev/ssl/nezasa-test.jks -Dhttps.keyStorePassword=nezasa-test -Djavax.net.ssl.trustStore=conf/truststore_dev.jks'
alias playdevworker="activator -mem 2496 -jvm-debug 9999 -Dconfig.file=/home/rethab/.application-dev.rethab.conf -Djavax.net.ssl.trustStore=conf/truststore_dev.jks 'runMain Worker'"
alias patchdev='source ~/dev/platform/etc/db/db_env.sh && mongo ${DEV_DB_HOST_PRIMARY}/${DEV_DB_NAME} -u ${DEV_DB_USER} -p${DEV_PASSWD} --ssl'
alias mongostart='sudo docker run -p 27017:27017 -v ~/data/mongo:/data/db -d mongo:3.4 --wiredTigerCacheSizeGB 1'
alias dbfetch='DUMP_DIR=/home/rethab/data/db-dumps etc/dev/db/update-local-db.sh -redownload'
alias irritant_ti='sbt -Dconfig.file="/home/rethab/.irritant.conf" "runMain com.irritant.Main notify-missing-test-instructions --git-path=/home/rethab/dev/platform --run-mode=dry"'
alias irritant_unresolved='sbt -Dconfig.file="/home/rethab/.irritant.conf" "runMain com.irritant.Main notify-unresolved-tickets --git-path=/home/rethab/dev/platform --run-mode=dry"'

PROJECT_PATH="~/dev/platform/"
alias mongo_dev="${PROJECT_PATH}/etc/dev/alias/mongo_dev.sh"
alias mongo_dev_clone="${PROJECT_PATH}/etc/release/cloneDatabase/cloneDatabase.sh --dev2local"
alias mongo_dev_dump="${PROJECT_PATH}/etc/dev/alias/mongo_dev_dump.sh"
alias mongo_dev_restore="${PROJECT_PATH}/etc/dev/alias/mongo_dev_restore.sh"
alias memclean="echo 'flush_all' | nc localhost 11211"
alias sbt='sbt -mem 2496'
