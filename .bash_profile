#
# ~/.bash_profile
#

[[ -f ~/.bashrc ]] && . ~/.bashrc

xscreensaver -no-splash &

if [[ ! $DISPLAY && $XDG_VTNR -eq 1 ]]; then
  exec startx
fi
