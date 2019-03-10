
# avoid urxvt warnings when sshing in the wild
export TERM='linux'

xrdb -merge ~/.Xresources

if [[ ! $DISPLAY && $XDG_VTNR -eq 1 ]]; then
  exec startx
fi
