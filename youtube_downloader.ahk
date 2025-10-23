#Requires AutoHotkey v2.0
#SingleInstance Force
SetWorkingDir(A_ScriptDir)

; Configuration file to remember last download location
global ConfigFile := A_ScriptDir "\downloader_config.ini"
global LastDownloadConfig := Map()

^!m::
{
    ; Check for updates on first run each session
    static UpdateChecked := false
    if (!UpdateChecked) {
        CheckAndUpdateTools()
        UpdateChecked := true
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

        btnProceed.OnEvent("Click", (*) => (channelVideoCount := Integer(videoCountEdit.Value), channelChoice :=
        "proceed", channelGui.Destroy()))
        btnCancelChannel.OnEvent("Click", (*) => (channelChoice := "cancel", channelGui.Destroy()))
        channelGui.OnEvent("Close", (*) => (channelChoice := "cancel", channelGui.Destroy()))

        channelGui.Show()
        WinWaitClose("ahk_id " channelGui.Hwnd)

        if (channelChoice = "cancel")
            return
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
        result := MsgBox("'yt-dlp.exe' not found in script folder.`n`nWould you like to download it automatically?",
            "yt-dlp Not Found", 4 + 48)
        if (result = "Yes") {
            toolsNeeded := ["yt-dlp"]

            ; Also check if FFmpeg is missing
            ffmpegInfo := GetFFmpegLocation()
            if !ffmpegInfo["found"] {
                ffmpegResult := MsgBox(
                    "FFmpeg is also not found.`n`nWould you like to download FFmpeg as well?`n(Recommended for MP4 downloads)",
                    "FFmpeg Also Missing", 4 + 32)
                if (ffmpegResult = "Yes") {
                    toolsNeeded.Push("ffmpeg")
                }
            }

            if !DownloadTools(toolsNeeded) {
                return
            }

            ; Show completion message
            if (toolsNeeded.Length > 1) {
                MsgBox("All tools have been successfully installed!`n`nYou can now start downloading videos.",
                    "Setup Complete", 64)
            }
        } else {
            MsgBox(
                "Download cancelled. You can download yt-dlp manually from:`nhttps://github.com/yt-dlp/yt-dlp/releases",
                "Cancelled", 48)
            return
        }
    }

    ; Step 4.5: Detect playlist link and ask user
    isPlaylist := false
    downloadWholePlaylist := false
    playlistVideoCount := 0

    if InStr(videoURL, "list=") && !isChannel {
        isPlaylist := true

        ; Check if URL contains a specific video ID (v= parameter)
        hasVideoID := InStr(videoURL, "v=") || RegExMatch(videoURL, "youtu\.be/[^/?]+")

        playlistGui := Gui("+AlwaysOnTop", "Playlist Detected")
        playlistGui.SetFont("s10")
        playlistGui.Add("Text", "w400", "Detected a playlist link!`n`nWhat would you like to do?")

        choice := ""

        ; Only show "Only Download This Video" if there's a specific video in the URL
        if (hasVideoID) {
            btnDownloadAll := playlistGui.Add("Button", "w180 h35 Default", "Download All")
            btnDownloadN := playlistGui.Add("Button", "w180 h35 x+20 yp", "Download First N Videos")
            btnSingleVideo := playlistGui.Add("Button", "w180 h35 xm", "Only Download This Video")
            btnAbort := playlistGui.Add("Button", "w180 h35 x+20 yp", "Abort")

            btnDownloadAll.OnEvent("Click", (*) => (choice := "all", playlistGui.Destroy()))
            btnDownloadN.OnEvent("Click", (*) => (choice := "n", playlistGui.Destroy()))
            btnSingleVideo.OnEvent("Click", (*) => (choice := "single", playlistGui.Destroy()))
            btnAbort.OnEvent("Click", (*) => (choice := "abort", playlistGui.Destroy()))
            playlistGui.OnEvent("Close", (*) => (choice := "abort", playlistGui.Destroy()))
        } else {
            btnDownloadAll := playlistGui.Add("Button", "w180 h35 Default", "Download All")
            btnDownloadN := playlistGui.Add("Button", "w180 h35 x+20 yp", "Download First N Videos")
            btnAbort := playlistGui.Add("Button", "w180 h35 xm y+10", "Abort")

            btnDownloadAll.OnEvent("Click", (*) => (choice := "all", playlistGui.Destroy()))
            btnDownloadN.OnEvent("Click", (*) => (choice := "n", playlistGui.Destroy()))
            btnAbort.OnEvent("Click", (*) => (choice := "abort", playlistGui.Destroy()))
            playlistGui.OnEvent("Close", (*) => (choice := "abort", playlistGui.Destroy()))
        }

        playlistGui.Show()
        WinWaitClose("ahk_id " playlistGui.Hwnd)

        if (choice = "abort")
            return
        else if (choice = "all")
            downloadWholePlaylist := true
        else if (choice = "n") {
            ; Ask for number of videos
            nVideosGui := Gui("+AlwaysOnTop", "How Many Videos?")
            nVideosGui.SetFont("s10")
            nVideosGui.Add("Text", "w400", "How many videos from the playlist would you like to download?")

            nVideosGui.Add("Text", "xm", "Number of videos:")
            nVideoEdit := nVideosGui.Add("Edit", "x+10 yp-3 w100 Number", "10")
            nVideosGui.Add("UpDown", "Range1-500", 10)

            btnProceedN := nVideosGui.Add("Button", "xm w180 h35 Default", "Download")
            btnCancelN := nVideosGui.Add("Button", "x+20 yp w180 h35", "Cancel")

            nChoice := ""

            btnProceedN.OnEvent("Click", (*) => (playlistVideoCount := Integer(nVideoEdit.Value), nChoice := "ok",
            nVideosGui.Destroy()))
            btnCancelN.OnEvent("Click", (*) => (nChoice := "cancel", nVideosGui.Destroy()))
            nVideosGui.OnEvent("Close", (*) => (nChoice := "cancel", nVideosGui.Destroy()))

            nVideosGui.Show()
            WinWaitClose("ahk_id " nVideosGui.Hwnd)

            if (nChoice = "cancel")
                return

            downloadWholePlaylist := true
        }
        else if (choice = "single") {
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

    ; Add channel-specific or playlist-specific parameters
    limitParams := ""
    if (isChannel) {
        limitParams := " --playlist-end " channelVideoCount
    } else if (playlistVideoCount > 0) {
        limitParams := " --playlist-end " playlistVideoCount
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
    ffmpegInfo := GetFFmpegLocation()

    if (ffmpegInfo["found"]) {
        ffmpegParam := ' --ffmpeg-location "' . ffmpegInfo["path"] . '"'
    } else {
        ; Show warning if FFmpeg not found
        result := MsgBox("Warning: FFmpeg not detected!`n`nSearched in:`n• " A_ScriptDir "\ffmpeg.exe`n• " A_ScriptDir "\ffmpeg\bin\ffmpeg.exe`n• " A_ScriptDir "\ffmpeg\ffmpeg.exe`n• System PATH`n`nFFmpeg is required to merge video and audio for MP4 downloads.`n`nContinue anyway?",
            "FFmpeg Not Found", 4 + 48)
        if (result != "Yes")
            return
    }

    ; Build command with proper escaping
    if (formatChoice = "mp3") {
        cmd := Format('yt-dlp.exe -f "{1}" -x --audio-format {2} -o "{3}" {4} {5} "{6}" 2> "{7}"',
            quality, container, outputTemplate, ffmpegParam, limitParams, videoURL, logFile)
    } else {
        cmd := Format('yt-dlp.exe -f "{1}" --merge-output-format {2} -o "{3}" {4} {5} "{6}" 2> "{7}"',
            quality, container, outputTemplate, ffmpegParam, limitParams, videoURL, logFile)
    }

    ; Determine download type for message
    downloadType := ""
    if (isChannel)
        downloadType := "channel (" channelVideoCount " videos)"
    else if (downloadWholePlaylist) {
        if (playlistVideoCount > 0)
            downloadType := "playlist (first " playlistVideoCount " videos)"
        else
            downloadType := "playlist"
    }
    else
        downloadType := (formatChoice = "mp3" ? "audio" : "video")

    ; Show starting message
    MsgBox("Starting download of " downloadType "...`n`nA terminal window will open.", "Starting Download", 64)

    ; Execute command with error handling
    try {
        fullCmd := 'cmd.exe /c "' . cmd . '"'
        exitCode := RunWait(fullCmd, , "")
    } catch as err {
        MsgBox("Failed to execute download command:`n" err.Message, "Execution Error", 16)
        return
    }

    ; Parse results
    downloadSuccess := (exitCode = 0)
    videosDownloaded := 0
    errorMessages := []
    warningMessages := []
    downloadedFiles := []

    if FileExist(logFile) {
        try {
            logContent := FileRead(logFile)

            ; Extract downloaded filenames
            loop parse, logContent, "`n", "`r" {
                line := Trim(A_LoopField)

                ; Look for merger completion or direct download completion
                if InStr(line, "[Merger] Merging formats into") || InStr(line, "[download] Destination:") {
                    ; Extract filename from log
                    if RegExMatch(line, 'into\s+"(.+?)"', &match)
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

            ; Safe deletion with retry
            try {
                FileDelete(logFile)
            } catch {
                ; Ignore deletion errors
            }
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
        if (isChannel) {
            notifMsg := channelVideoCount " video(s) downloaded from channel!" filesText warningText "`n`nSaved to: " SavePath
        } else if (downloadWholePlaylist) {
            contentType := (formatChoice = "mp3") ? "audio file(s)" : "video(s)"
            notifMsg := videosDownloaded " " contentType " downloaded from playlist!" filesText warningText "`n`nSaved to: " SavePath
        } else {
            contentType := (formatChoice = "mp3") ? "audio" : "video"
            notifMsg := "Your " contentType " has been downloaded successfully!" filesText warningText "`n`nSaved to: " SavePath
        }

        ; Show message with option to open folder
        result := MsgBox(notifMsg "`n`nOpen download folder?", "Download Complete", 4 + 64)
        if (result = "Yes")
            Run('explorer.exe "' SavePath '"')
    } else {
        if (downloadWholePlaylist && videosDownloaded > 0) {
            MsgBox("Download was interrupted!`n`nOnly " videosDownloaded " video(s) were downloaded." errorText,
                "Download Incomplete", 48)
        } else if (videosDownloaded > 0 && !hasError) {
            contentType := (formatChoice = "mp3") ? "audio file(s)" : "video(s)"
            result := MsgBox("Download completed with warnings.`n`n" videosDownloaded " " contentType " were downloaded." warningText "`n`nOpen download folder?",
                "Download Warning", 4 + 48)
            if (result = "Yes")
                Run('explorer.exe "' SavePath '"')
        } else {
            MsgBox("Download failed!" errorText "`n`nCommon solutions:`n• Check your internet connection`n• Verify the video URL is valid`n• Check if video is region-locked or private`n• Ensure FFmpeg is installed correctly`n• Try a different quality setting",
                "Download Failed", 16)
        }
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
        ; Normalize the path using Loop Files
        try {
            loop files, lastPath, "D" {
                lastPath := A_LoopFileFullPath
                break
            }
        } catch {
            lastPath := A_MyDocuments
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
    ; Normalize path using Loop Files
    normalizedPath := quickPath
    try {
        loop files, quickPath, "D" {
            normalizedPath := A_LoopFileFullPath
            break
        }
    }

    if DirExist(normalizedPath) {
        editControl.Value := normalizedPath
        pathVar := normalizedPath
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

; Helper function to get FFmpeg location
GetFFmpegLocation() {
    result := Map("found", false, "path", "", "location", "")

    ; Check 1: Script directory
    if FileExist(A_ScriptDir "\ffmpeg.exe") {
        result["found"] := true
        result["path"] := A_ScriptDir
        result["location"] := A_ScriptDir "\ffmpeg.exe"
        return result
    }
    ; Check 2: ffmpeg\bin subfolder
    else if FileExist(A_ScriptDir "\ffmpeg\bin\ffmpeg.exe") {
        result["found"] := true
        result["path"] := A_ScriptDir "\ffmpeg\bin"
        result["location"] := A_ScriptDir "\ffmpeg\bin\ffmpeg.exe"
        return result
    }
    ; Check 3: ffmpeg folder (without bin)
    else if FileExist(A_ScriptDir "\ffmpeg\ffmpeg.exe") {
        result["found"] := true
        result["path"] := A_ScriptDir "\ffmpeg"
        result["location"] := A_ScriptDir "\ffmpeg\ffmpeg.exe"
        return result
    }
    ; Check 4: System PATH
    else {
        try {
            exitResult := RunWait('cmd.exe /c ffmpeg -version > nul 2>&1', , "Hide")
            if (exitResult = 0) {
                result["found"] := true
                result["path"] := ""
                result["location"] := "System PATH"
                return result
            }
        }
    }

    return result
}

; Function to check and update yt-dlp and ffmpeg
CheckAndUpdateTools() {
    toolsToDownload := []

    ; Check if yt-dlp exists
    if !FileExist(A_ScriptDir "\yt-dlp.exe") {
        toolsToDownload.Push("yt-dlp")
    } else {
        ; Get current version and check for updates
        try {
            currentVersion := GetCurrentYtDlpVersion()
            latestVersion := GetLatestYtDlpVersion()

            if (latestVersion != "" && currentVersion != latestVersion) {
                result := MsgBox("A new version of yt-dlp is available!`n`nCurrent: " currentVersion "`nLatest: " latestVersion "`n`nWould you like to update now?",
                    "Update Available", 4 + 64)
                if (result = "Yes") {
                    toolsToDownload.Push("yt-dlp")
                }
            } else if (latestVersion != "") {
                ToolTip("✓ yt-dlp is up to date (" currentVersion ")")
                SetTimer(() => ToolTip(), -2000)
            }
        } catch as err {
            ToolTip("Could not check for yt-dlp updates: " err.Message)
            SetTimer(() => ToolTip(), -3000)
        }
    }

    ; Always check FFmpeg (detect, check version, offer update)
    ffmpegInfo := GetFFmpegLocation()
    if !ffmpegInfo["found"] {
        ; FFmpeg not found - offer to download
        result := MsgBox(
            "FFmpeg not found!`n`nFFmpeg is required to merge video and audio for MP4 downloads.`n`nWould you like to download it automatically?",
            "FFmpeg Not Found", 4 + 48)
        if (result = "Yes") {
            toolsToDownload.Push("ffmpeg")
        }
    } else {
        ; FFmpeg exists - check for updates
        try {
            currentFFmpegVersion := GetCurrentFFmpegVersion(ffmpegInfo["location"])
            latestFFmpegVersion := GetLatestFFmpegVersion()

            if (latestFFmpegVersion != "" && currentFFmpegVersion != "" && currentFFmpegVersion != latestFFmpegVersion) {
                result := MsgBox("A new version of FFmpeg is available!`n`nCurrent: " currentFFmpegVersion "`nLatest: " latestFFmpegVersion "`n`nWould you like to update now?",
                    "FFmpeg Update Available", 4 + 64)
                if (result = "Yes") {
                    toolsToDownload.Push("ffmpeg")
                }
            } else if (currentFFmpegVersion != "") {
                ToolTip("✓ FFmpeg is up to date (" currentFFmpegVersion ")")
                SetTimer(() => ToolTip(), -2000)
            }
        } catch as err {
            ; Just show version found without update check
            ToolTip("✓ FFmpeg found")
            SetTimer(() => ToolTip(), -2000)
        }
    }

    ; Download all missing/outdated tools together
    if (toolsToDownload.Length > 0) {
        DownloadTools(toolsToDownload)
    }
}

; Function to get current FFmpeg version
GetCurrentFFmpegVersion(ffmpegLocation) {
    try {
        versionFile := A_Temp "\ffmpeg_version_check.txt"
        try FileDelete(versionFile)

        if (ffmpegLocation = "System PATH") {
            RunWait('cmd.exe /c ffmpeg -version > "' versionFile '" 2>&1', , "Hide")
        } else {
            RunWait('cmd.exe /c "' ffmpegLocation '" -version > "' versionFile '" 2>&1', , "Hide")
        }

        if FileExist(versionFile) {
            versionContent := FileRead(versionFile)
            try FileDelete(versionFile)

            ; Extract version from "ffmpeg version N-xxxxx-..." or "ffmpeg version x.x.x"
            if RegExMatch(versionContent, "ffmpeg version\s+([^\s]+)", &match) {
                return match[1]
            }
        }
    }
    return ""
}

; Function to get latest FFmpeg version from GitHub
GetLatestFFmpegVersion() {
    try {
        apiUrl := "https://api.github.com/repos/BtbN/FFmpeg-Builds/releases/latest"
        tempApiFile := A_Temp "\ffmpeg_latest_release.json"
        try FileDelete(tempApiFile)

        Download(apiUrl, tempApiFile)

        if FileExist(tempApiFile) {
            jsonContent := FileRead(tempApiFile)
            try FileDelete(tempApiFile)

            ; Parse JSON to get tag_name (version)
            if RegExMatch(jsonContent, '"tag_name":\s*"([^"]+)"', &match) {
                version := match[1]
                return version
            }
        }
    } catch as err {
        ; Silent fail - will return empty string
    }
    return ""
}

; Function to get current yt-dlp version
GetCurrentYtDlpVersion() {
    try {
        RunWait('cmd.exe /c "' A_ScriptDir '\yt-dlp.exe" --version > "' A_Temp '\ytdlp_current_version.txt" 2>&1', ,
            "Hide")
        if FileExist(A_Temp "\ytdlp_current_version.txt") {
            version := FileRead(A_Temp "\ytdlp_current_version.txt")
            version := Trim(version)
            try FileDelete(A_Temp "\ytdlp_current_version.txt")
            return version
        }
    }
    return ""
}

; Function to get latest yt-dlp version from GitHub
GetLatestYtDlpVersion() {
    try {
        ; Use GitHub API to get latest release
        apiUrl := "https://api.github.com/repos/yt-dlp/yt-dlp/releases/latest"

        ; Download API response
        tempFile := A_Temp "\ytdlp_latest_release.json"
        try FileDelete(tempFile)

        Download(apiUrl, tempFile)

        if FileExist(tempFile) {
            jsonContent := FileRead(tempFile)
            try FileDelete(tempFile)

            ; Parse JSON to get tag_name (version)
            if RegExMatch(jsonContent, '"tag_name":\s*"([^"]+)"', &match) {
                version := match[1]
                ; Remove 'v' prefix if present
                version := RegExReplace(version, "^v", "")
                return version
            }
        }
    } catch as err {
        ; Silent fail - will return empty string
    }
    return ""
}

; Function to download multiple tools together
DownloadTools(toolsList) {
    if (toolsList.Length = 0)
        return true

    totalTools := toolsList.Length
    currentTool := 0
    allSuccess := true

    for tool in toolsList {
        currentTool++

        if (tool = "yt-dlp") {
            if !DownloadYtDlp(currentTool, totalTools)
                allSuccess := false
        } else if (tool = "ffmpeg") {
            if !DownloadFFmpeg(currentTool, totalTools)
                allSuccess := false
        }
    }

    return allSuccess
}

; Function to download yt-dlp with progress bar
DownloadYtDlp(currentNum := 1, totalNum := 1) {
    ; Always get the latest download URL from GitHub API
    latestDownloadUrl := ""

    try {
        apiUrl := "https://api.github.com/repos/yt-dlp/yt-dlp/releases/latest"
        tempApiFile := A_Temp "\ytdlp_api_response.json"
        try FileDelete(tempApiFile)

        Download(apiUrl, tempApiFile)

        if FileExist(tempApiFile) {
            jsonContent := FileRead(tempApiFile)
            try FileDelete(tempApiFile)

            ; Parse JSON to find the yt-dlp.exe download URL
            if RegExMatch(jsonContent, '"browser_download_url":\s*"([^"]*yt-dlp\.exe)"', &match) {
                latestDownloadUrl := match[1]
            }
        }
    }

    ; Fallback to direct latest URL if API fails
    if (latestDownloadUrl = "") {
        latestDownloadUrl := "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe"
    }

    tempFile := A_Temp "\yt-dlp_new.exe"
    finalFile := A_ScriptDir "\yt-dlp.exe"

    ; Create progress GUI
    progressTitle := (totalNum > 1) ? "Downloading Tools (" currentNum "/" totalNum ")" : "Downloading yt-dlp"
    progressGui := Gui("+AlwaysOnTop -MinimizeBox", progressTitle)
    progressGui.SetFont("s10")
    progressGui.Add("Text", "w400 Center", "Downloading yt-dlp...")
    statusText := progressGui.Add("Text", "w400 Center", "Preparing download...")
    progressBar := progressGui.Add("Progress", "w400 h30", 0)
    percentText := progressGui.Add("Text", "w400 Center", "0%")

    progressGui.Show()

    ; Delete temp file if exists
    try FileDelete(tempFile)

    ; Start download
    downloadComplete := false
    downloadError := false
    errorMsg := ""
    progressValue := 0

    ; Update progress function
    UpdateProgress() {
        if (downloadComplete || downloadError) {
            SetTimer(UpdateProgress, 0)
            return
        }

        ; Simulate progress since we can't get real progress
        if (progressValue < 90) {
            progressValue += 5
            try {
                progressBar.Value := progressValue
                percentText.Value := progressValue "%"
                statusText.Value := "Downloading... (" progressValue "%)"
            }
        }
    }

    ; Perform download in try-catch
    SetTimer(UpdateProgress, 100)

    try {
        Download(latestDownloadUrl, tempFile)
        downloadComplete := true
    } catch as err {
        downloadError := true
        errorMsg := err.Message
    }

    ; Wait for download to complete
    while (!downloadComplete && !downloadError) {
        Sleep(100)
    }

    SetTimer(UpdateProgress, 0)

    if (downloadError) {
        progressGui.Destroy()
        MsgBox("Failed to download yt-dlp:`n" errorMsg "`n`nPlease download manually from:`nhttps://github.com/yt-dlp/yt-dlp/releases",
            "Download Failed", 16)
        return false
    }

    ; Set to 100%
    try {
        progressBar.Value := 100
        percentText.Value := "100%"
        statusText.Value := "Installing..."
    }
    Sleep(500)

    ; Move file to script directory
    try {
        ; Backup old version if exists
        if FileExist(finalFile) {
            try FileMove(finalFile, A_ScriptDir "\yt-dlp_backup.exe", 1)
        }

        FileMove(tempFile, finalFile, 1)

        progressGui.Destroy()

        ; Get new version
        newVersion := GetCurrentYtDlpVersion()
        versionText := (newVersion != "") ? " (version " newVersion ")" : ""

        if (totalNum = 1) {
            MsgBox("yt-dlp has been successfully downloaded and installed!" versionText, "Installation Complete", 64)
        }

        ; Delete backup
        try FileDelete(A_ScriptDir "\yt-dlp_backup.exe")

        return true
    } catch as err {
        progressGui.Destroy()

        ; Restore backup if move failed
        if FileExist(A_ScriptDir "\yt-dlp_backup.exe") {
            try FileMove(A_ScriptDir "\yt-dlp_backup.exe", finalFile, 1)
        }

        MsgBox("Failed to install yt-dlp:`n" err.Message, "Installation Failed", 16)
        return false
    }
}

; Function to download FFmpeg with progress bar
DownloadFFmpeg(currentNum := 1, totalNum := 1) {
    ; Get latest FFmpeg release URL
    latestDownloadUrl := ""

    try {
        apiUrl := "https://api.github.com/repos/BtbN/FFmpeg-Builds/releases/latest"
        tempApiFile := A_Temp "\ffmpeg_api_response.json"
        try FileDelete(tempApiFile)

        Download(apiUrl, tempApiFile)

        if FileExist(tempApiFile) {
            jsonContent := FileRead(tempApiFile)
            try FileDelete(tempApiFile)

            ; Look for ffmpeg-master-latest-win64-gpl.zip
            if RegExMatch(jsonContent, '"browser_download_url":\s*"([^"]*ffmpeg-master-latest-win64-gpl\.zip)"', &match
            ) {
                latestDownloadUrl := match[1]
            }
        }
    }

    ; Fallback URL
    if (latestDownloadUrl = "") {
        latestDownloadUrl :=
            "https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl.zip"
    }

    tempZip := A_Temp "\ffmpeg_download.zip"
    extractPath := A_Temp "\ffmpeg_extract"
    finalPath := A_ScriptDir "\ffmpeg"

    ; Create progress GUI
    progressTitle := (totalNum > 1) ? "Downloading Tools (" currentNum "/" totalNum ")" : "Downloading FFmpeg"
    progressGui := Gui("+AlwaysOnTop -MinimizeBox", progressTitle)
    progressGui.SetFont("s10")
    progressGui.Add("Text", "w400 Center", "Downloading FFmpeg...")
    statusText := progressGui.Add("Text", "w400 Center", "Preparing download...")
    progressBar := progressGui.Add("Progress", "w400 h30", 0)
    percentText := progressGui.Add("Text", "w400 Center", "0%")

    progressGui.Show()

    ; Clean up temp files
    try FileDelete(tempZip)
    try DirDelete(extractPath, 1)

    ; Start download
    downloadComplete := false
    downloadError := false
    errorMsg := ""
    progressValue := 0

    ; Update progress function
    UpdateProgressFFmpeg() {
        if (downloadComplete || downloadError) {
            SetTimer(UpdateProgressFFmpeg, 0)
            return
        }

        if (progressValue < 90) {
            progressValue += 3
            try {
                progressBar.Value := progressValue
                percentText.Value := progressValue "%"
                statusText.Value := "Downloading... (" progressValue "%)"
            }
        }
    }

    SetTimer(UpdateProgressFFmpeg, 100)

    try {
        Download(latestDownloadUrl, tempZip)
        downloadComplete := true
    } catch as err {
        downloadError := true
        errorMsg := err.Message
    }

    ; Wait for download
    while (!downloadComplete && !downloadError) {
        Sleep(100)
    }

    SetTimer(UpdateProgressFFmpeg, 0)

    if (downloadError) {
        progressGui.Destroy()
        MsgBox("Failed to download FFmpeg:`n" errorMsg, "Download Failed", 16)
        return false
    }

    ; Extract
    try {
        progressBar.Value := 95
        percentText.Value := "95%"
        statusText.Value := "Extracting..."

        ; Create extraction directory
        DirCreate(extractPath)

        ; Extract using PowerShell
        extractCmd := 'powershell -command "Expand-Archive -Path ' '' tempZip '' ' -DestinationPath ' '' extractPath '' ' -Force"'
        RunWait(extractCmd, , "Hide")

        ; Find the bin folder
        binFound := false
        loop files, extractPath "\*", "D" {
            binPath := A_LoopFileFullPath "\bin"
            if DirExist(binPath) {
                ; Move bin contents to script folder
                try DirCreate(finalPath)

                loop files, binPath "\*.*" {
                    try FileMove(A_LoopFileFullPath, finalPath "\" A_LoopFileName, 1)
                }
                binFound := true
                break
            }
        }

        if (!binFound) {
            throw Error("Could not find FFmpeg binaries in archive")
        }

        progressBar.Value := 100
        percentText.Value := "100%"
        statusText.Value := "Complete!"
        Sleep(500)

        ; Cleanup
        try FileDelete(tempZip)
        try DirDelete(extractPath, 1)

        progressGui.Destroy()

        if (totalNum = 1) {
            MsgBox("FFmpeg has been successfully downloaded and installed!", "Installation Complete", 64)
        }

        return true
    } catch as err {
        progressGui.Destroy()
        try FileDelete(tempZip)
        try DirDelete(extractPath, 1)
        MsgBox("Failed to extract FFmpeg:`n" err.Message, "Extraction Failed", 16)
        return false
    }
}
