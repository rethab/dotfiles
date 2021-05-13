# Linux
alias ls='ls -G'
alias cp='cp -i'
alias mv='mv -i'
alias ln='ln -i'
alias dmesg='dmesg --human'
alias :q='exit'
alias grep='grep --color=always'
alias grop='grep --color=never'
alias sudo='sudo -E'
alias csvawk='awk -v FPAT="([^,]*)|(\"([^\"]|\"\")+\")"'
alias plainvim='vim -u NONE'

alias weather='curl wttr.in'

# Urxvt
alias bigfont="printf '\33]50;%s\007' \"xft:Terminus:pixelsize=20\""

# Git
alias g='git grep'
alias gl='git status'
alias go='git checkout'
alias gum='go master && git pull && go -'
alias gc='git add . && git commit -m '

# Arch
alias Y='yaourt'

function popup() { zenity --info --title "Kabooom" --text "$1" --timeout=2; }
