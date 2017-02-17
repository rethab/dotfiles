# Path to your oh-my-zsh configuration.
ZSH=/usr/share/oh-my-zsh/

export NVM_AUTO_USE=true

# systemd: creates alias sc-xx=systemctl xx
plugins=(colored-man zsh-nvm)

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
path+=('/usr/local/heroku/bin')
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
alias gu='go develop && git pull && go -'

alias lala='echo "use gl"'

alias unlockssh='eval $(ssh-agent) && ssh-add'

# Arch
alias Y='yaourt'


# https://github.com/zsh-users/zsh-syntax-highlighting
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# https://github.com/rupa/z
export _Z_DATA=~/.z/data
source ~/dev/z/z.sh

# arch linux java switching
source /etc/profile.d/jre.sh


### Aliases for Nezasa dev
alias playdev='activator -mem 2496 -jvm-debug 9999 -Dconfig.file=conf/application-dev.${USER}.conf -Dhttps.port=9443 -Dhttps.keyStore=etc/dev/ssl/nezasa-test.jks -Dhttps.keyStorePassword=nezasa-test -Djavax.net.ssl.trustStore=conf/truststore_dev.jks'
alias playdevworker='activator -mem 2496 -jvm-debug 9999 -Dconfig.file=conf/application-dev.${USER}.conf -Dapplication.global=Worker -Djavax.net.ssl.trustStore=conf/truststore_dev.jks'
alias patchdev='source ~/dev/platform/etc/db/db_env.sh && mongo ${DEV_DB_HOST_PRIMARY}/${DEV_DB_NAME} -u ${DEV_DB_USER} -p${DEV_PASSWD} --ssl --sslCAFile ~/dev/platform/etc/db/ssl/${DEV_DB_SSL_CA_FILE}'
alias mongostart='sudo docker run -p 27017:27017 -v ~/data/mongo:/data/db -v ~/dev/platform:/data/platform -d rethab/mongo-3.2.10'

(echo $SBT_OPTS | grep Trireme > /dev/null) && { echo 'Warn: Using Trireme'; } 

PROJECT_PATH="~/dev/platform/"
alias mongo_dev="${PROJECT_PATH}/etc/dev/alias/mongo_dev.sh"
alias mongo_dev_clone="${PROJECT_PATH}/etc/release/cloneDatabase/cloneDatabase.sh --local"
alias mongo_dev_dump="${PROJECT_PATH}/etc/dev/alias/mongo_dev_dump.sh"
alias mongo_dev_restore="${PROJECT_PATH}/etc/dev/alias/mongo_dev_restore.sh"
alias memclean="echo 'flush_all' | nc localhost 11211"
alias sbt='sbt -mem 2496'
