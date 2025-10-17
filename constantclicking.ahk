#Requires AutoHotkey v2.0

toggle := false

F8:: {
    global toggle
    toggle := !toggle
    if (toggle) {
        SetTimer(ClickLoop, 10)
    } else {
        SetTimer(ClickLoop, 0)
    }
}

ClickLoop() {
    Click "left"
}
