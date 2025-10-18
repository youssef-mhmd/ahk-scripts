;Mouse4 (The front thumb button) will reset mothon attributes in premiere.
;It works by selceting Effects Controls -> looking up for a default motion preset -> dragging it onto saved mouse position.
;So position mouse over the clip you want to reset when doing this.


#Requires Autohotkey v2.0

DllCall("SetProcessDpiAwarenessContext", "ptr", -4) ; Enable DPI awareness

#HotIf WinActive("Adobe Premiere Pro")

XButton2:: ; Mouse5 (XButton1 is usually the "Back" button on most mice)
{
    ; Set coordinate mode to "Window"
    CoordMode "Mouse", "Windows"

    ; Save original mouse position (relative to Premiere window)
    MouseGetPos &origX, &origY

    ; Step 1: Send Shift + X twice
    Send "+x"
    Sleep 10

    ; Step 2: Send Shift + F
    Send "+f"
    Sleep 10

    ; Step 3: Select existing text and paste "Default Motion"
    A_Clipboard := "Default Motion"
    Sleep 1
    Send "^a"
    Sleep 10
    Send "^v"
    sleep 20

    ; Step 4: Drag from (185, 332) in the windows to original postion
    MouseMove 153, 272, 0
    Sleep 10
    MouseClick "Left", , , 1, 0, "D"
    Sleep 10
    MouseMove origX, origY, 10
    Sleep 10
    MouseClick "Left", , , 1, 0, "U"
}

#HotIf


return
