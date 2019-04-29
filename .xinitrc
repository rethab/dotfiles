#!/bin/bash

xsetroot -cursor_name left_ptr
xset mouse 5 1
xscreensaver -no-splash &
xrdb -merge ~/.Xresources

exec xmonad
