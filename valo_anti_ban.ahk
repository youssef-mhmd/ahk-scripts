; AutoHotkey v2 Script - Toggle Hold W with F8

#Requires AutoHotkey v2.0

; Initialize toggle state
wToggle := false

; F8 hotkey to toggle W key
F8::
{
    global wToggle
    wToggle := !wToggle  ; Toggle the state
    
    if (wToggle) {
        Send("{w down}")  ; Press and hold W
    } else {
        Send("{w up}")  ; Release W
    }
}

; Optional: Exit script with Ctrl+Esc
^Esc::ExitApp