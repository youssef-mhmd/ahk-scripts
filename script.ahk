#Requires AutoHotkey v2.0
#SingleInstance Force
SetWorkingDir(A_ScriptDir)

;------------------------------------------------------

; ^ Ctrl
; + Shift
; # Win
; ! Alt

;------------------------------------------------------

!Right:: Send("{End}")
!+Right:: Send("+{End}")

!Left:: Send("{Home}")
!+Left:: Send("+{Home}")

!Backspace:: Send("+{Home}{Delete}")

;------------------------------------------------------

^!t:: run "wt.exe"

;------------------------------------------------------

#w:: Send("!{F4}")

;------------------------------------------------------

#^b:: run "chrome.exe"

;------------------------------------------------------

!WheelUp:: {
    SoundSetVolume(SoundGetVolume() + 3)
}
!WheelDown:: {
    SoundSetVolume(SoundGetVolume() - 3)
}

;------------------------------------------------------

!m:: SoundSetMute(!SoundGetMute())

;------------------------------------------------------

scriptFile := A_ScriptFullPath
lastModified := FileGetTime(scriptFile, "M")

SetTimer(CheckReload, 1000) ; check every second

CheckReload() {
    global scriptFile, lastModified
    newModified := FileGetTime(scriptFile, "M")
    if (newModified != lastModified) {
        lastModified := newModified
        Reload()
    }
}

;------------------------------------------------------
