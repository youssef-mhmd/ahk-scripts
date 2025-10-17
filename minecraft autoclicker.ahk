#Requires AutoHotkey v2.0

SetTimer(CheckMinecraft, 1000) ; Check every second

CheckMinecraft() {
    ; Check if the Minecraft window is open
    if (WinExist("Minecraft")) {
        ; Send M1 (mouse click) every 10 seconds
        static lastClickTime := 0
        currentTime := A_TickCount

        if (currentTime - lastClickTime >= 10000) ; 1000 millisecond = 10 seconds
        {
            Click "left" ; Send mouse click (M1)
            lastClickTime := currentTime ; Update click time
        }
    }
}
