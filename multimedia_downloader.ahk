#Requires AutoHotkey v2.0
#SingleInstance Force
SetWorkingDir(A_ScriptDir)

+S::
{
    ; CONSULTANT NOTE: Change this path to your exact Downloads folder if necessary
    FixedSavePath := "C:\Users\jousef\Downloads"

    ; Step 1: Copy URL from browser
    oldClipboard := A_Clipboard
    A_Clipboard := ""
    Send("^l")
    Sleep(150)
    Send("^c")
    ClipWait(1)
    videoURL := A_Clipboard
    A_Clipboard := oldClipboard

    ; Step 2: Validate URL
    if (videoURL = "" || !InStr(videoURL, "http")) {
        MsgBox("Could not get a valid URL from the browser.`nPlease try again.", "Error", 48)
        return
    }

    ; Step 3: Confirm
    result := MsgBox("Are you sure this is the right link?`n`n" videoURL, "Confirm Download", 4 + 32)
    if (result != "Yes")
        return

    ; Step 3.5: Choose format (MP3 or MP4)
    formatGui := Gui("+AlwaysOnTop", "Choose Download Format")
    formatGui.SetFont("s10")
    formatGui.Add("Text", "w400", "What format would you like to download?")

    btnMP4 := formatGui.Add("Button", "w180 h35 Default", "MP4 (Video)")
    btnMP3 := formatGui.Add("Button", "w180 h35 x+20 yp", "MP3 (Audio Only)")
    btnCancel := formatGui.Add("Button", "w180 h35 xm", "Cancel")

    formatChoice := ""

    btnMP4.OnEvent("Click", (*) => (formatChoice := "mp4", formatGui.Destroy()))
    btnMP3.OnEvent("Click", (*) => (formatChoice := "mp3", formatGui.Destroy()))
    btnCancel.OnEvent("Click", (*) => (formatChoice := "cancel", formatGui.Destroy()))
    formatGui.OnEvent("Close", (*) => (formatChoice := "cancel", formatGui.Destroy()))

    formatGui.Show()
    WinWaitClose("ahk_id " formatGui.Hwnd)

    if (formatChoice = "cancel")
        return

    ; Step 3.6: If MP4, choose quality
    videoQuality := ""
    if (formatChoice = "mp4") {
        qualityGui := Gui("+AlwaysOnTop", "Choose Video Quality")
        qualityGui.SetFont("s10")
        qualityGui.Add("Text", "w400", "Select video quality:")

        btn4K := qualityGui.Add("Button", "w120 h35 Default", "4K (2160p)")
        btn1440p := qualityGui.Add("Button", "w120 h35 x+10 yp", "1440p")
        btn1080p := qualityGui.Add("Button", "w120 h35 x+10 yp", "1080p")

        btn720p := qualityGui.Add("Button", "w120 h35 xm", "720p")
        btnBest := qualityGui.Add("Button", "w120 h35 x+10 yp", "Best Available")
        btnQualityCancel := qualityGui.Add("Button", "w120 h35 x+10 yp", "Cancel")

        btn4K.OnEvent("Click", (*) => (videoQuality := "2160", qualityGui.Destroy()))
        btn1440p.OnEvent("Click", (*) => (videoQuality := "1440", qualityGui.Destroy()))
        btn1080p.OnEvent("Click", (*) => (videoQuality := "1080", qualityGui.Destroy()))
        btn720p.OnEvent("Click", (*) => (videoQuality := "720", qualityGui.Destroy()))
        btnBest.OnEvent("Click", (*) => (videoQuality := "best", qualityGui.Destroy()))
        btnQualityCancel.OnEvent("Click", (*) => (videoQuality := "cancel", qualityGui.Destroy()))
        qualityGui.OnEvent("Close", (*) => (videoQuality := "cancel", qualityGui.Destroy()))

        qualityGui.Show()
        WinWaitClose("ahk_id " qualityGui.Hwnd)

        if (videoQuality = "cancel")
            return
    }

    ; Step 4: Check for path and yt-dlp
    if !DirExist(FixedSavePath) {
        MsgBox("The save folder doesn't exist:`n" FixedSavePath, "Error", 16)
        return
    }
    if !FileExist("yt-dlp.exe") {
        MsgBox("'yt-dlp.exe' not found in script folder.", "Error", 16)
        return
    }

    ; Step 4.5: Detect playlist link and ask user
    isPlaylist := false
    downloadWholePlaylist := false

    if InStr(videoURL, "list=") {
        isPlaylist := true

        ; Create custom dialog with specific button names
        playlistGui := Gui("+AlwaysOnTop", "Playlist Detected")
        playlistGui.SetFont("s10")
        playlistGui.Add("Text", "w400", "Detected a playlist link!`n`nWhat would you like to do?")

        btnDownloadAll := playlistGui.Add("Button", "w180 h35 Default", "Download All")
        btnSingleVideo := playlistGui.Add("Button", "w180 h35 x+20 yp", "Only Download This Video")
        btnAbort := playlistGui.Add("Button", "w180 h35 xm", "Abort")

        choice := ""

        btnDownloadAll.OnEvent("Click", (*) => (choice := "all", playlistGui.Destroy()))
        btnSingleVideo.OnEvent("Click", (*) => (choice := "single", playlistGui.Destroy()))
        btnAbort.OnEvent("Click", (*) => (choice := "abort", playlistGui.Destroy()))
        playlistGui.OnEvent("Close", (*) => (choice := "abort", playlistGui.Destroy()))

        playlistGui.Show()
        WinWaitClose("ahk_id " playlistGui.Hwnd)

        if (choice = "abort")
            return
        else if (choice = "all")
            downloadWholePlaylist := true
        else ; single
        {
            ; Remove playlist parameter to download only single video
            videoURL := RegExReplace(videoURL, "&list=[^&]*", "")
            videoURL := RegExReplace(videoURL, "\?list=[^&]*&?", "?")
            videoURL := RegExReplace(videoURL, "\?list=[^&]*$", "")
        }
    }

    ; Step 5: Prepare yt-dlp command
    if (formatChoice = "mp3") {
        quality := "bestaudio/best"
        container := "mp3"
    } else {
        ; Build quality string based on user selection
        if (videoQuality = "best") {
            quality := "bestvideo+bestaudio/best"
        } else {
            quality := "bestvideo[height<=" videoQuality "]+bestaudio/best"
        }
        container := "mp4"
    }

    ; Create a temporary log file to capture output
    logFile := A_Temp "\yt-dlp_log_" A_TickCount ".txt"

    ; Set output template based on playlist or single video
    if (formatChoice = "mp4") {
        qualityTag := (videoQuality = "best") ? "" : "_" videoQuality "p"
        if (downloadWholePlaylist)
            outputTemplate := FixedSavePath "\%(playlist_title)s\%(title)s" qualityTag ".%(ext)s"
        else
            outputTemplate := FixedSavePath "\%(title)s" qualityTag ".%(ext)s"
    } else {
        if (downloadWholePlaylist)
            outputTemplate := FixedSavePath "\%(playlist_title)s\%(title)s.%(ext)s"
        else
            outputTemplate := FixedSavePath "\%(title)s.%(ext)s"
    }

    ; Add ffmpeg location - check multiple possible locations
    ffmpegParam := ""
    ffmpegFound := false
    ffmpegLocation := ""

    ; Check 1: Script directory
    if FileExist(A_ScriptDir "\ffmpeg.exe") {
        ; Ensure the path is correctly quoted for the command line
        ffmpegParam := ' --ffmpeg-location "' . A_ScriptDir . '"'
        ffmpegFound := true
        ffmpegLocation := A_ScriptDir "\ffmpeg.exe"
    }
    ; Check 2: ffmpeg\bin subfolder
    else if FileExist(A_ScriptDir "\ffmpeg\bin\ffmpeg.exe") {
        ffmpegParam := ' --ffmpeg-location "' . A_ScriptDir . '\ffmpeg\bin"'
        ffmpegFound := true
        ffmpegLocation := A_ScriptDir "\ffmpeg\bin\ffmpeg.exe"
    }
    ; Check 3: ffmpeg folder (without bin)
    else if FileExist(A_ScriptDir "\ffmpeg\ffmpeg.exe") {
        ffmpegParam := ' --ffmpeg-location "' . A_ScriptDir . '\ffmpeg"'
        ffmpegFound := true
        ffmpegLocation := A_ScriptDir "\ffmpeg\ffmpeg.exe"
    }
    ; Check 4: System PATH (yt-dlp will find it automatically)
    else {
        ; Try to run ffmpeg to see if it's in PATH
        try {
            ; Check is done silently
            result := RunWait('cmd.exe /c ffmpeg -version > nul 2>&1', , "Hide")
            if (result = 0) {
                ffmpegFound := true
                ffmpegLocation := "System PATH"
            }
        }
    }

    ; Show debug info
    if (!ffmpegFound) {
        result := MsgBox("Warning: FFmpeg not detected!`n`nSearched in:`n• " A_ScriptDir "\ffmpeg.exe`n• " A_ScriptDir "\ffmpeg\bin\ffmpeg.exe`n• " A_ScriptDir "\ffmpeg\ffmpeg.exe`n• System PATH`n`nFFmpeg is required to merge video and audio.`n`nContinue anyway?",
            "FFmpeg Not Found", 4 + 48)
        if (result != "Yes")
            return
    }

    ; Build command with error logging
    if (formatChoice = "mp3") {
        cmd := Format('yt-dlp.exe -f "{1}" -x --audio-format {2} -o "{3}" {4} "{5}" 2> "{6}"',
            quality, container, outputTemplate, ffmpegParam, videoURL, logFile)
    } else {
        cmd := Format('yt-dlp.exe -f "{1}" --merge-output-format {2} -o "{3}" {4} "{5}" 2> "{6}"',
            quality, container, outputTemplate, ffmpegParam, videoURL, logFile)
    }

    ; Step 6: Start download (visible progress)
    if (downloadWholePlaylist)
        MsgBox(
            "Downloading playlist... A terminal window will open.`n`nThe window will close automatically when finished.",
            "Starting Playlist Download", 64)
    else
        MsgBox(
            "Download starting... A terminal window will open.`n`nThe window will close automatically when finished.",
            "Starting Download", 64)

    ; **** THE CRUCIAL FIX IS HERE ****
    ; We wrap the complex command in cmd.exe /c to ensure the OS shell properly handles
    ; all the nested double quotes (especially for file paths and parameters).
    fullCmd := 'cmd.exe /c "' . cmd . '"'
    exitCode := RunWait(fullCmd, , "") ; Note: The empty string '' here keeps the command prompt window visible

    ; Step 7: Parse results and notify
    downloadSuccess := (exitCode = 0)

    ; Try to count downloaded videos and extract errors from log
    videosDownloaded := 0
    errorMessages := []
    warningMessages := []

    ; Temporarily allow the log file to remain if you need to manually debug a failure!
    if FileExist(logFile) {
        logContent := FileRead(logFile)

        ; Count successful downloads by looking for merge/download completion messages
        loop parse, logContent, "`n", "`r" {
            line := Trim(A_LoopField)

            ; Count downloads
            if InStr(line, "Merging formats into") || InStr(line, "has already been downloaded") || InStr(line,
                "[download] 100%")
                videosDownloaded++

            ; Collect ERROR messages
            if InStr(line, "ERROR:") {
                errorMsg := RegExReplace(line, "^.*ERROR:\s*", "")
                if (errorMsg != "" && errorMsg != line)
                    errorMessages.Push(errorMsg)
            }

            ; Collect WARNING messages
            if InStr(line, "WARNING:") {
                warnMsg := RegExReplace(line, "^.*WARNING:\s*", "")
                if (warnMsg != "" && warnMsg != line && !InStr(warnMsg, "unable to download video info webpage"))
                    warningMessages.Push(warnMsg)
            }
        }

        ; Check for common specific errors in the log
        if InStr(logContent, "ffmpeg") && InStr(logContent, "not found")
            errorMessages.Push("FFmpeg not found - required for merging video and audio")
        if InStr(logContent, "HTTP Error 403") || InStr(logContent, "403 Forbidden")
            errorMessages.Push("Access denied (403) - video may be region-locked or private")
        if InStr(logContent, "Video unavailable")
            errorMessages.Push("Video is unavailable")
        if InStr(logContent, "Private video")
            errorMessages.Push("This is a private video")
        if InStr(logContent, "Sign in to confirm")
            errorMessages.Push("Age-restricted video - sign-in required")

        ; Clean up log file (UNCOMMENT the line below once testing is complete)
        ;try FileDelete(logFile)
    }

    ; Remove duplicate error messages
    uniqueErrors := Map()
    for err in errorMessages
        uniqueErrors[err] := true
    errorMessages := []
    for err in uniqueErrors
        errorMessages.Push(err)

    ; Build error/warning display text
    errorText := ""
    if (errorMessages.Length > 0) {
        errorText := "`n`nErrors encountered:"
        for err in errorMessages
            errorText .= "`n• " err
    }

    warningText := ""
    if (warningMessages.Length > 0 && warningMessages.Length <= 3) {
        warningText := "`n`nWarnings:"
        for warn in warningMessages
            warningText .= "`n• " warn
    }

    ; Show appropriate message
    hasError := (errorMessages.Length > 0)

    if (downloadSuccess && !hasError) {
        if (downloadWholePlaylist) {
            if (videosDownloaded > 0)
                MsgBox(videosDownloaded " video(s) downloaded successfully from the playlist!" warningText,
                    "Download Complete", 64)
            else
                MsgBox("Playlist download completed!" warningText, "Download Complete", 64)
        }
        else {
            MsgBox("Your video has been downloaded successfully!" warningText, "Download Complete", 64)
        }
    }
    else {
        ; Download failed or was interrupted
        if (downloadWholePlaylist && videosDownloaded > 0) {
            MsgBox("Download was interrupted!`n`nOnly " videosDownloaded " video(s) were downloaded from the playlist." errorText,
                "Download Incomplete", 48)
        }
        else if (videosDownloaded > 0 && !hasError) {
            MsgBox("Download completed with warnings.`n`n" videosDownloaded " video(s) were downloaded." warningText,
                "Download Warning", 48)
        }
        else {
            MsgBox("Download failed!" errorText "`n`nCommon solutions:`n• Check your internet connection`n• Verify the video URL is valid`n• Check if video is region-locked or private`n• Ensure FFmpeg is installed correctly",
                "Download Failed", 16)
        }
    }
}
