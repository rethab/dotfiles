import Data.Maybe                ( fromJust )
import XMonad
import XMonad.Actions.WindowGo   ( runOrRaise )
import XMonad.Hooks.DynamicLog   ( dynamicLogWithPP
                                 , xmobarColor
                                 , shorten
                                 , ppTitle
                                 , ppOutput
                                 , xmobarPP )
import XMonad.Hooks.SetWMName    ( setWMName)
import XMonad.Hooks.ManageDocks  ( avoidStruts, manageDocks)
import XMonad.Layout.ResizableTile (ResizableTall(..), MirrorResize(..))
import XMonad.Layout.Named (named)
import XMonad.Layout.NoBorders (smartBorders)
import XMonad.Util.Run           ( spawnPipe, runInTerm)
import XMonad.Util.EZConfig      ( additionalKeys)
import XMonad.Hooks.EwmhDesktops ( ewmh )
import XMonad.Actions.CycleWS    ( moveTo
                                 , shiftTo
                                 , nextWS
                                 , prevWS
                                 , Direction1D (Next)
                                 , WSType(EmptyWS))

import qualified XMonad.StackSet as W

import System.IO

main = do
    -- start xmonad with default config file
    xmproc <- spawnPipe "xmobar"
    xmonad $ defaultConfig
        {
          -- support for status bar and dock
          manageHook = manageDocks <+> myManageHook
                   <+> manageHook defaultConfig
        , startupHook = setWMName "LG3D"
        , terminal = "terminology"
        , layoutHook = myLayoutHook

          -- get output to xmobar with hPutStrLn xmproc
          -- put first 50 characters of the windows title to the title area
        , logHook = dynamicLogWithPP xmobarPP
                            { ppOutput = hPutStrLn xmproc
                            , ppTitle  = xmobarColor "green" "" . shorten 50
                            }
        } `additionalKeys`
        concat [ keybindings, multihead]



myManageHook = composeAll
    [ className =? "Gimp"     --> doFloat
    ]
        
-- rename windows key
linKey = mod4Mask

-- rename alt key
altKey = mod1Mask

keybindings = 
        [
          -- lock with ctrl-alt-l
          ((altKey .|. controlMask, xK_l ), spawn "xscreensaver-command --lock")

        -- workspace movements
        , ((altKey,               xK_n), moveTo  Next EmptyWS)
        , ((altKey .|. shiftMask, xK_n), shiftTo Next EmptyWS)
        , ((altKey,               xK_y), prevWS)
        , ((altKey,               xK_u), nextWS)
        
          -- unclutter and un-unclutter
        , ((linKey, xK_o ), spawn "unclutter -grab -idle 0")
        , ((linKey, xK_i ), spawn "killall unclutter")

        -- resize current window
        , ((altKey .|. shiftMask, xK_h), sendMessage MirrorExpand)
        , ((altKey .|. shiftMask, xK_l), sendMessage MirrorShrink)

        -- keyboard layout switch
        , ((linKey, xK_u), spawn "setxkbmap us")
        , ((linKey, xK_s), spawn "setxkbmap ch")

        -- applications
        , ((linKey, xK_f), runOrRaise "firefox" (className =? "Firefox"))
        , ((linKey, xK_r), spawn redshift)
        , ((linKey, xK_d), spawn dropboxstart)
        , ((linKey, xK_p), spawn "sleep 0.2; scrot -s")

        ]

redshift = "redshift -l 47.523809:9.0882"
dropboxstart = "dropbox-cli start"

multihead= [ ((m .|. altKey, k), windows $ f i)
                 | (i, k) <- zip myWorkspaces [xK_1 .. xK_9]
                 , (f, m) <- [(W.view, 0), (W.shift, shiftMask)]]
    where myWorkspaces = map show [1..9]

myLayoutHook =
    -- avoid overlapping xmonbar
    avoidStruts $

    -- borders disappean on fullscreen
    smartBorders $

    -- available layouts
    myResizableTall ||| myResizableMirrorTall ||| Full
  where myResizableTall       = named "Tall" $
                                ResizableTall 1 0.03 0.5 []
        myResizableMirrorTall = named "Mirror Tall" $
                                Mirror (ResizableTall 1 0.03 0.5 [])
