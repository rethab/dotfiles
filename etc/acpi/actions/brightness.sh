#!/bin/sh

export XAUTHORITY=/home/rethab/.Xauthority 
export DISPLAY=:0.0 
step=15

case "$1" in 
    inc) xbacklight -inc $step 2>/tmp/brightness-err ;;
    dec) xbacklight -dec $step 2>/tmp/brightness-err ;;
esac
