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

; Configuration file to remember last download location
global ConfigFile := A_ScriptDir "\downloader_config.ini"
global DownloadQueue := []
global IsDownloading := false
global LastDownloadConfig := Map()

^!m::
{
    ; Check for updates on first run each session
    static UpdateChecked := false
    if (!UpdateChecked) {
        CheckAndUpdateTools()
        UpdateChecked := true
    }

    ; If currently downloading, ask to add to queue
    if (IsDownloading) {
        result := MsgBox("A download is currently in progress.`n`nDo you want to add this video to the download queue?",
            "Add to Queue?", 4 + 32)
        if (result != "Yes")
            return
    }

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

    ; Step 2.5: Detect if it's a channel URL
    isChannel := InStr(videoURL, "/@") || InStr(videoURL, "/channel/") || InStr(videoURL, "/c/") || InStr(videoURL,
        "/user/")
    channelVideoCount := 0

    if (isChannel) {
        channelGui := Gui("+AlwaysOnTop", "YouTube Channel Detected")
        channelGui.SetFont("s10")
        channelGui.Add("Text", "w400",
            "This is a YouTube channel link!`n`nHow many recent videos would you like to download?")

        channelGui.Add("Text", "xm", "Number of videos:")
        videoCountEdit := channelGui.Add("Edit", "x+10 yp-3 w100 Number", "50")
        channelGui.Add("UpDown", "Range1-500", 50)

        btnProceed := channelGui.Add("Button", "xm w180 h35 Default", "Download Videos")
        btnCancelChannel := channelGui.Add("Button", "x+20 yp w180 h35", "Cancel")

        channelChoice := ""

        btnProceed.OnEvent("Click", (*) => (channelChoice := "proceed", channelGui.Destroy()))
        btnCancelChannel.OnEvent("Click", (*) => (channelChoice := "cancel", channelGui.Destroy()))
        channelGui.OnEvent("Close", (*) => (channelChoice := "cancel", channelGui.Destroy()))

        channelGui.Show()
        WinWaitClose("ahk_id " channelGui.Hwnd)

        if (channelChoice = "cancel")
            return

        channelVideoCount := Integer(videoCountEdit.Value)
    }

    ; Step 3: Confirm
    result := MsgBox("Are you sure this is the right link?`n`n" videoURL, "Confirm Download", 4 + 32)
    if (result != "Yes")
        return

    ; Step 3.5: Choose format (MP3 or MP4) - or use last config
    formatChoice := ""
    videoQuality := ""
    SavePath := ""
    useSameConfig := false

    ; Check if we have last download config
    if (LastDownloadConfig.Has("format") && !isChannel) {
        lastFormat := LastDownloadConfig["format"]
        lastQuality := LastDownloadConfig.Has("quality") ? LastDownloadConfig["quality"] : "N/A"
        lastPath := LastDownloadConfig.Has("path") ? LastDownloadConfig["path"] : "N/A"

        configMsg := "Use the same settings as last download?`n`n"
        configMsg .= "Format: " (lastFormat = "mp3" ? "MP3 (Audio)" : "MP4 (Video)") "`n"
        if (lastFormat = "mp4")
            configMsg .= "Quality: " (lastQuality = "best" ? "Best Available" : lastQuality "p") "`n"
        configMsg .= "Location: " lastPath

        result := MsgBox(configMsg, "Repeat Last Settings?", 4 + 32)
        if (result = "Yes") {
            useSameConfig := true
            formatChoice := lastFormat
            if (lastFormat = "mp4")
                videoQuality := lastQuality
            SavePath := lastPath
        }
    }

    ; If not using same config, ask for format
    if (!useSameConfig) {
        formatGui := Gui("+AlwaysOnTop", "Choose Download Format")
        formatGui.SetFont("s10")
        formatGui.Add("Text", "w400", "What format would you like to download?")

        btnMP4 := formatGui.Add("Button", "w180 h35 Default", "MP4 (Video)")
        btnMP3 := formatGui.Add("Button", "w180 h35 x+20 yp", "MP3 (Audio Only)")
        btnCancel := formatGui.Add("Button", "w180 h35 xm", "Cancel")

        btnMP4.OnEvent("Click", (*) => (formatChoice := "mp4", formatGui.Destroy()))
        btnMP3.OnEvent("Click", (*) => (formatChoice := "mp3", formatGui.Destroy()))
        btnCancel.OnEvent("Click", (*) => (formatChoice := "cancel", formatGui.Destroy()))
        formatGui.OnEvent("Close", (*) => (formatChoice := "cancel", formatGui.Destroy()))

        formatGui.Show()
        WinWaitClose("ahk_id " formatGui.Hwnd)

        if (formatChoice = "cancel")
            return

        ; Step 3.6: Get download location (after format is chosen)
        SavePath := GetDownloadLocation(formatChoice)
        if (SavePath = "")
            return

        ; Step 3.7: If MP4, choose quality
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
    }

    ; Save current config for next time
    LastDownloadConfig["format"] := formatChoice
    LastDownloadConfig["quality"] := videoQuality
    LastDownloadConfig["path"] := SavePath

    ; Step 4: Check for yt-dlp
    if !FileExist("yt-dlp.exe") {
        MsgBox(
            "'yt-dlp.exe' not found in script folder.`n`nPlease download it from:`nhttps://github.com/yt-dlp/yt-dlp/releases",
            "Error", 16)
        return
    }

    ; Step 4.5: Detect playlist link and ask user
    isPlaylist := false
    downloadWholePlaylist := false

    if InStr(videoURL, "list=") && !isChannel {
        isPlaylist := true

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
        else {
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
        if (videoQuality = "best") {
            quality := "bestvideo+bestaudio/best"
        } else {
            quality := "bestvideo[height<=" videoQuality "]+bestaudio/best"
        }
        container := "mp4"
    }

    ; Add channel-specific parameters
    channelParams := ""
    if (isChannel) {
        channelParams := " --playlist-end " channelVideoCount
    }

    ; Create a temporary log file to capture output
    logFile := A_Temp "\yt-dlp_log_" A_TickCount ".txt"

    ; Sanitize the save path for special characters
    SafeSavePath := SanitizePath(SavePath)

    ; Set output template based on playlist or single video
    if (formatChoice = "mp4") {
        qualityTag := (videoQuality = "best") ? "" : "_" videoQuality "p"
        if (downloadWholePlaylist || isChannel)
            outputTemplate := SafeSavePath "\%(playlist_title,channel)s\%(title)s" qualityTag ".%(ext)s"
        else
            outputTemplate := SafeSavePath "\%(title)s" qualityTag ".%(ext)s"
    } else {
        if (downloadWholePlaylist || isChannel)
            outputTemplate := SafeSavePath "\%(playlist_title,channel)s\%(title)s.%(ext)s"
        else
            outputTemplate := SafeSavePath "\%(title)s.%(ext)s"
    }

    ; Add ffmpeg location - check multiple possible locations
    ffmpegParam := ""
    ffmpegFound := false
    ffmpegLocation := ""

    ; Check 1: Script directory
    if FileExist(A_ScriptDir "\ffmpeg.exe") {
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
    ; Check 4: System PATH
    else {
        try {
            result := RunWait('cmd.exe /c ffmpeg -version > nul 2>&1', , "Hide")
            if (result = 0) {
                ffmpegFound := true
                ffmpegLocation := "System PATH"
            }
        }
    }

    ; Show warning if FFmpeg not found
    if (!ffmpegFound) {
        result := MsgBox("Warning: FFmpeg not detected!`n`nSearched in:`n• " A_ScriptDir "\ffmpeg.exe`n• " A_ScriptDir "\ffmpeg\bin\ffmpeg.exe`n• " A_ScriptDir "\ffmpeg\ffmpeg.exe`n• System PATH`n`nFFmpeg is required to merge video and audio for MP4 downloads.`n`nContinue anyway?",
            "FFmpeg Not Found", 4 + 48)
        if (result != "Yes")
            return
    }

    ; Build command with proper escaping
    if (formatChoice = "mp3") {
        cmd := Format('yt-dlp.exe -f "{1}" -x --audio-format {2} -o "{3}" {4} {5} "{6}" 2> "{7}"',
            quality, container, outputTemplate, ffmpegParam, channelParams, videoURL, logFile)
    } else {
        cmd := Format('yt-dlp.exe -f "{1}" --merge-output-format {2} -o "{3}" {4} {5} "{6}" 2> "{7}"',
            quality, container, outputTemplate, ffmpegParam, channelParams, videoURL, logFile)
    }

    ; Create download task
    downloadTask := Map(
        "url", videoURL,
        "cmd", cmd,
        "logFile", logFile,
        "savePath", SavePath,
        "format", formatChoice,
        "quality", videoQuality,
        "isPlaylist", downloadWholePlaylist,
        "isChannel", isChannel,
        "channelCount", channelVideoCount
    )

    ; Add to queue
    DownloadQueue.Push(downloadTask)

    ; If not currently downloading, start processing
    if (!IsDownloading) {
        ProcessDownloadQueue()
    } else {
        MsgBox("Added to download queue!`n`nPosition in queue: " DownloadQueue.Length, "Queued", 64)
    }
}

; Function to process download queue
ProcessDownloadQueue() {
    if (DownloadQueue.Length = 0) {
        IsDownloading := false
        return
    }

    IsDownloading := true
    task := DownloadQueue[1]
    DownloadQueue.RemoveAt(1)

    ; Determine download type for message
    downloadType := ""
    if (task["isChannel"])
        downloadType := "channel (" task["channelCount"] " videos)"
    else if (task["isPlaylist"])
        downloadType := "playlist"
    else
        downloadType := (task["format"] = "mp3" ? "audio" : "video")

    ; Show starting message
    queueInfo := (DownloadQueue.Length > 0) ? "`n`n" DownloadQueue.Length " more in queue" : ""
    MsgBox("Starting download of " downloadType "...`n`nA terminal window will open." queueInfo, "Starting Download",
        64)

    ; Execute command
    fullCmd := 'cmd.exe /c "' . task["cmd"] . '"'
    exitCode := RunWait(fullCmd, , "")

    ; Parse results
    downloadSuccess := (exitCode = 0)
    videosDownloaded := 0
    errorMessages := []
    warningMessages := []
    downloadedFiles := []

    if FileExist(task["logFile"]) {
        try {
            logContent := FileRead(task["logFile"])

            ; Extract downloaded filenames
            loop parse, logContent, "`n", "`r" {
                line := Trim(A_LoopField)

                ; Look for merger completion or direct download completion
                if InStr(line, "[Merger] Merging formats into") || InStr(line, "[download] Destination:") {
                    ; Extract filename from log
                    if RegExMatch(line, "into\s+" "(.+?)" "", &match)
                        downloadedFiles.Push(match[1])
                    else if RegExMatch(line, "Destination:\s+(.+)$", &match)
                        downloadedFiles.Push(match[1])
                }

                if InStr(line, "Merging formats into") || InStr(line, "has already been downloaded") || InStr(line,
                    "[download] 100%")
                    videosDownloaded++

                if InStr(line, "ERROR:") {
                    errorMsg := RegExReplace(line, "^.*ERROR:\s*", "")
                    if (errorMsg != "" && errorMsg != line)
                        errorMessages.Push(errorMsg)
                }

                if InStr(line, "WARNING:") {
                    warnMsg := RegExReplace(line, "^.*WARNING:\s*", "")
                    if (warnMsg != "" && warnMsg != line && !InStr(warnMsg, "unable to download video info webpage"))
                        warningMessages.Push(warnMsg)
                }
            }

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

            try FileDelete(task["logFile"])
        }
    }

    ; Remove duplicate errors
    uniqueErrors := Map()
    for err in errorMessages
        uniqueErrors[err] := true
    errorMessages := []
    for err, _ in uniqueErrors
        errorMessages.Push(err)

    ; Build notification message
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

    ; Build downloaded files list
    filesText := ""
    if (downloadedFiles.Length > 0 && downloadedFiles.Length <= 5) {
        filesText := "`n`nDownloaded:`n"
        for file in downloadedFiles {
            SplitPath(file, &filename)
            filesText .= "• " filename "`n"
        }
    } else if (downloadedFiles.Length > 5) {
        filesText := "`n`n" downloadedFiles.Length " files downloaded"
    }

    hasError := (errorMessages.Length > 0)

    ; Show completion message with Open Folder button
    if (downloadSuccess && !hasError) {
        if (task["isChannel"]) {
            notifMsg := task["channelCount"] " video(s) downloaded from channel!" filesText warningText "`n`nSaved to: " task[
                "savePath"]
        } else if (task["isPlaylist"]) {
            contentType := (task["format"] = "mp3") ? "audio file(s)" : "video(s)"
            notifMsg := videosDownloaded " " contentType " downloaded from playlist!" filesText warningText "`n`nSaved to: " task[
                "savePath"]
        } else {
            contentType := (task["format"] = "mp3") ? "audio" : "video"
            notifMsg := "Your " contentType " has been downloaded successfully!" filesText warningText "`n`nSaved to: " task[
                "savePath"]
        }

        ; Show message with option to open folder
        result := MsgBox(notifMsg "`n`nOpen download folder?", "Download Complete", 4 + 64)
        if (result = "Yes")
            Run('explorer.exe "' task["savePath"] '"')
    } else {
        if (task["isPlaylist"] && videosDownloaded > 0) {
            MsgBox("Download was interrupted!`n`nOnly " videosDownloaded " video(s) were downloaded." errorText,
                "Download Incomplete", 48)
        } else if (videosDownloaded > 0 && !hasError) {
            contentType := (task["format"] = "mp3") ? "audio file(s)" : "video(s)"
            result := MsgBox("Download completed with warnings.`n`n" videosDownloaded " " contentType " were downloaded." warningText "`n`nOpen download folder?",
                "Download Warning", 4 + 48)
            if (result = "Yes")
                Run('explorer.exe "' task["savePath"] '"')
        } else {
            MsgBox("Download failed!" errorText "`n`nCommon solutions:`n• Check your internet connection`n• Verify the video URL is valid`n• Check if video is region-locked or private`n• Ensure FFmpeg is installed correctly`n• Try a different quality setting",
                "Download Failed", 16)
        }
    }

    ; Process next in queue
    if (DownloadQueue.Length > 0) {
        SetTimer(() => ProcessDownloadQueue(), -1000)  ; Wait 1 second before next download
    } else {
        IsDownloading := false
    }
}

; Function to get or select download location with memory
GetDownloadLocation(formatType := "mp4") {
    ; Try to read last used location from config file
    lastPath := ""
    if FileExist(ConfigFile) {
        try {
            lastPath := IniRead(ConfigFile, "Settings", "LastDownloadPath", "")
        }
    }

    ; If no saved path or path doesn't exist, use default Downloads folder
    if (lastPath = "" || !DirExist(lastPath)) {
        lastPath := A_MyDocuments "\..\Downloads"
        ; Normalize the path
        try {
            lastPath := FileExist(lastPath) ? lastPath : A_MyDocuments
        }
    }

    ; Create modern, flexible GUI for location selection
    locationGui := Gui("+AlwaysOnTop -MinimizeBox", "Select Download Location")
    locationGui.SetFont("s10")
    locationGui.BackColor := "0xF0F0F0"

    ; Header with icon and title
    formatName := (formatType = "mp3") ? "Audio (MP3)" : "Video (MP4)"
    locationGui.Add("Text", "w550 h40 +Center", "Choose where to save your " formatName " file")
    locationGui.SetFont("s9")

    ; Current path display
    locationGui.Add("Text", "xm+10 w80", "Save to:")
    pathEdit := locationGui.Add("Edit", "x+10 yp-3 w450 h25", lastPath)

    ; Quick access buttons section
    locationGui.Add("GroupBox", "xm w570 h90", "Quick Access")

    btnDownloads := locationGui.Add("Button", "xm+15 yp+25 w130 h30", "Downloads")
    btnDesktop := locationGui.Add("Button", "x+10 yp w130 h30", "Desktop")
    btnDocuments := locationGui.Add("Button", "x+10 yp w130 h30", "Documents")
    btnVideos := locationGui.Add("Button", "x+10 yp w130 h30", "Videos")

    btnMusic := locationGui.Add("Button", "xm+15 y+10 w130 h30", "Music")
    btnLastUsed := locationGui.Add("Button", "x+10 yp w130 h30", "Use Last Location")
    btnCustom := locationGui.Add("Button", "x+10 yp w270 h30", "Browse...")

    ; Action buttons
    locationGui.Add("Text", "xm w570 h1 +0x10")  ; Separator line
    btnConfirm := locationGui.Add("Button", "xm+130 y+15 w150 h35 Default", "Confirm Location")
    btnCancel := locationGui.Add("Button", "x+20 yp w150 h35", "Cancel")

    selectedPath := lastPath
    userChoice := ""

    ; Quick access button handlers
    btnDownloads.OnEvent("Click", (*) => SetQuickPath(pathEdit, &selectedPath, A_MyDocuments "\..\Downloads"))
    btnDesktop.OnEvent("Click", (*) => SetQuickPath(pathEdit, &selectedPath, A_Desktop))
    btnDocuments.OnEvent("Click", (*) => SetQuickPath(pathEdit, &selectedPath, A_MyDocuments))
    btnVideos.OnEvent("Click", (*) => SetQuickPath(pathEdit, &selectedPath, A_MyDocuments "\Videos"))
    btnMusic.OnEvent("Click", (*) => SetQuickPath(pathEdit, &selectedPath, A_MyDocuments "\Music"))
    btnCustom.OnEvent("Click", (*) => BrowseForFolder(pathEdit, &selectedPath))
    btnLastUsed.OnEvent("Click", (*) => SetQuickPath(pathEdit, &selectedPath, lastPath))

    ; Main action buttons
    btnConfirm.OnEvent("Click", (*) => (selectedPath := pathEdit.Value, userChoice := "ok", locationGui.Destroy()))
    btnCancel.OnEvent("Click", (*) => (userChoice := "cancel", locationGui.Destroy()))
    locationGui.OnEvent("Close", (*) => (userChoice := "cancel", locationGui.Destroy()))

    ; Allow editing the path directly
    pathEdit.OnEvent("Change", (*) => (selectedPath := pathEdit.Value))

    locationGui.Show("w590")
    WinWaitClose("ahk_id " locationGui.Hwnd)

    if (userChoice = "cancel")
        return ""

    ; Validate the selected path
    if !DirExist(selectedPath) {
        result := MsgBox("The selected folder doesn't exist.`n`nWould you like to create it?", "Create Folder?", 4 + 32
        )
        if (result = "Yes") {
            try {
                DirCreate(selectedPath)
            } catch as err {
                MsgBox("Failed to create folder:`n" err.Message, "Error", 16)
                return ""
            }
        } else {
            return ""
        }
    }

    ; Save the selected path to config file
    try {
        IniWrite(selectedPath, ConfigFile, "Settings", "LastDownloadPath")
    }

    return selectedPath
}

; Helper function to set quick access paths
SetQuickPath(editControl, &pathVar, quickPath) {
    ; Normalize path
    if InStr(quickPath, "..\") {
        try {
            ; Resolve relative paths
            SplitPath(quickPath, , &dir)
            loop files, quickPath, "D" {
                quickPath := A_LoopFileFullPath
                break
            }
        }
    }

    if DirExist(quickPath) {
        editControl.Value := quickPath
        pathVar := quickPath
    } else {
        MsgBox("Folder not found: " quickPath, "Path Error", 48)
    }
}

; Helper function for folder browser
BrowseForFolder(editControl, &pathVar) {
    ; Get the GUI handle before opening dialog
    guiHwnd := editControl.Gui.Hwnd

    ; Temporarily hide the GUI to prevent z-order issues
    WinHide("ahk_id " guiHwnd)

    selectedFolder := DirSelect("*" editControl.Value, 3, "Select Download Folder")

    ; Show the GUI again
    WinShow("ahk_id " guiHwnd)
    WinActivate("ahk_id " guiHwnd)

    if (selectedFolder != "") {
        editControl.Value := selectedFolder
        pathVar := selectedFolder
    }
}

; Function to sanitize paths for command line usage
SanitizePath(path) {
    ; Remove any trailing backslashes
    path := RTrim(path, "\")
    ; Escape any special characters if needed
    return path
}

; Function to check and update yt-dlp and ffmpeg
CheckAndUpdateTools() {
    updateMsg := ""

    ; Check yt-dlp
    if FileExist("yt-dlp.exe") {
        try {
            ; Get current version
            RunWait('cmd.exe /c yt-dlp.exe --version > "' A_Temp '\ytdlp_version.txt" 2>&1', , "Hide")
            currentVersion := ""
            if FileExist(A_Temp "\ytdlp_version.txt") {
                currentVersion := FileRead(A_Temp "\ytdlp_version.txt")
                currentVersion := Trim(currentVersion)
                FileDelete(A_Temp "\ytdlp_version.txt")
            }

            ; Check for update
            updateMsg .= "Checking yt-dlp for updates...`n"
            exitCode := RunWait('cmd.exe /c yt-dlp.exe -U 2>&1 | findstr /C:"up to date" /C:"Updated" /C:"ERROR"', ,
                "Hide")

            if (exitCode = 0) {
                updateMsg .= "✓ yt-dlp is up to date`n"
            } else {
                updateMsg .= "✓ yt-dlp updated successfully`n"
            }
        } catch {
            updateMsg .= "⚠ Could not check yt-dlp version`n"
        }
    } else {
        updateMsg .= "✗ yt-dlp.exe not found`n"
    }

    ; Check ffmpeg
    ffmpegFound := false
    ffmpegPath := ""

    if FileExist(A_ScriptDir "\ffmpeg.exe") {
        ffmpegFound := true
        ffmpegPath := A_ScriptDir "\ffmpeg.exe"
    } else if FileExist(A_ScriptDir "\ffmpeg\bin\ffmpeg.exe") {
        ffmpegFound := true
        ffmpegPath := A_ScriptDir "\ffmpeg\bin\ffmpeg.exe"
    } else if FileExist(A_ScriptDir "\ffmpeg\ffmpeg.exe") {
        ffmpegFound := true
        ffmpegPath := A_ScriptDir "\ffmpeg\ffmpeg.exe"
    }

    if (ffmpegFound) {
        try {
            ; Get ffmpeg version
            RunWait('cmd.exe /c "' ffmpegPath '" -version > "' A_Temp '\ffmpeg_version.txt" 2>&1', , "Hide")
            if FileExist(A_Temp "\ffmpeg_version.txt") {
                versionContent := FileRead(A_Temp "\ffmpeg_version.txt")
                if RegExMatch(versionContent, "ffmpeg version ([^\s]+)", &match) {
                    updateMsg .= "✓ FFmpeg found (version " match[1] ")`n"
                } else {
                    updateMsg .= "✓ FFmpeg found`n"
                }
                FileDelete(A_Temp "\ffmpeg_version.txt")
            } else {
                updateMsg .= "✓ FFmpeg found`n"
            }

            ; Note: FFmpeg doesn't have an auto-update feature like yt-dlp
            updateMsg .= "  (Note: FFmpeg updates must be done manually)`n"
        } catch {
            updateMsg .= "⚠ FFmpeg found but couldn't verify version`n"
        }
    } else {
        ; Check system PATH
        try {
            result := RunWait('cmd.exe /c ffmpeg -version > nul 2>&1', , "Hide")
            if (result = 0) {
                updateMsg .= "✓ FFmpeg found in system PATH`n"
            } else {
                updateMsg .= "✗ FFmpeg not found`n"
            }
        } catch {
            updateMsg .= "✗ FFmpeg not found`n"
        }
    }

    ; Show update status if there's anything to report
    if (updateMsg != "") {
        ToolTip(updateMsg)
        SetTimer(() => ToolTip(), -3000)  ; Hide after 3 seconds
    }
}

;------------------------------------------------------
