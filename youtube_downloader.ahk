#Requires AutoHotkey v2.0
#SingleInstance Force
SetWorkingDir(A_ScriptDir)

; Configuration file to remember last download location
global ConfigFile := A_ScriptDir "\downloader_config.ini"

; Load configuration from INI file
LoadConfig() {
    config := Map()

    ; Check if config file exists, create if not
    if !FileExist(ConfigFile) {
        ; Create default config
        try {
            IniWrite("", ConfigFile, "MP3", "LastPath")
            IniWrite("", ConfigFile, "MP4", "LastPath")
            IniWrite("", ConfigFile, "MP4", "LastQuality")
        }
    }

    ; Load MP3 settings
    try {
        config["mp3_path"] := IniRead(ConfigFile, "MP3", "LastPath", "")
    } catch {
        config["mp3_path"] := ""
    }

    ; Load MP4 settings
    try {
        config["mp4_path"] := IniRead(ConfigFile, "MP4", "LastPath", "")
        config["mp4_quality"] := IniRead(ConfigFile, "MP4", "LastQuality", "")
    } catch {
        config["mp4_path"] := ""
        config["mp4_quality"] := ""
    }

    return config
}

; Save configuration to INI file
SaveConfig(format, path, quality := "") {
    try {
        if (format = "mp3") {
            IniWrite(path, ConfigFile, "MP3", "LastPath")
        } else if (format = "mp4") {
            IniWrite(path, ConfigFile, "MP4", "LastPath")
            IniWrite(quality, ConfigFile, "MP4", "LastQuality")
        }
    } catch as err {
        ; Silent fail - don't interrupt workflow
    }
}

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

    ; Step 3.5: Load configuration FIRST
    Config := LoadConfig()

    formatChoice := ""
    videoQuality := ""
    SavePath := ""
    useSameConfig := false

    ; Ask for format FIRST
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

    ; NOW check if we have last config for THIS format
    if (formatChoice = "mp3" && Config["mp3_path"] != "" && !isChannel) {
        configMsg := "Use the same settings as last MP3 download?`n`n"
        configMsg .= "Format: MP3 (Audio)`n"
        configMsg .= "Location: " Config["mp3_path"]

        result := MsgBox(configMsg, "Repeat Last MP3 Settings?", 4 + 32)
        if (result = "Yes") {
            useSameConfig := true
            SavePath := Config["mp3_path"]
        }
    } else if (formatChoice = "mp4" && Config["mp4_path"] != "" && !isChannel) {
        lastQuality := Config["mp4_quality"]

        configMsg := "Use the same settings as last MP4 download?`n`n"
        configMsg .= "Format: MP4 (Video)`n"
        configMsg .= "Quality: " (lastQuality = "best" ? "Best Available" : lastQuality "p") "`n"
        configMsg .= "Location: " Config["mp4_path"]

        result := MsgBox(configMsg, "Repeat Last MP4 Settings?", 4 + 32)
        if (result = "Yes") {
            useSameConfig := true
            videoQuality := lastQuality
            SavePath := Config["mp4_path"]
        }
    }

    ; If not using same config, ask for location and quality
    if (!useSameConfig) {
        ; Get download location (pass format for better defaults)
        SavePath := GetDownloadLocation(formatChoice, Config)
        if (SavePath = "")
            return

        ; If MP4, choose quality
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

    ; Save current config for next time (format-specific)
    SaveConfig(formatChoice, SavePath, videoQuality)

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

    ; Create logs folder in script directory
    logsFolder := A_ScriptDir "\logs"
    if !DirExist(logsFolder) {
        try DirCreate(logsFolder)
    }

    ; Create permanent log file with timestamp
    timestamp := FormatTime(, "yyyy-MM-dd_HHmmss")
    permanentLogFile := logsFolder "\download_" timestamp ".txt"

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
        ffmpegParam := ' --ffmpeg-location "' ffmpegInfo["path"] '"'
    } else {
        ; Show warning if FFmpeg not found
        result := MsgBox("Warning: FFmpeg not detected!`n`nSearched in:`n• " A_ScriptDir "\ffmpeg.exe`n• " A_ScriptDir "\ffmpeg\bin\ffmpeg.exe`n• " A_ScriptDir "\ffmpeg\ffmpeg.exe`n• System PATH`n`nFFmpeg is required to merge video and audio for MP4 downloads.`n`nContinue anyway?",
            "FFmpeg Not Found", 4 + 48)
        if (result != "Yes")
            return
    }

    ; Build command with proper escaping - REMOVE "& pause" to auto-close terminal
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
    MsgBox("Starting download of " downloadType "...`n`nA terminal window will open and close automatically.",
        "Starting Download", 64)

    ; Execute command with visible terminal and error handling
    try {
        fullCmd := 'cmd.exe /c "' cmd '"'
        exitCode := RunWait(fullCmd, , "")
    } catch as err {
        MsgBox("Failed to execute download command:`n" err.Message, "Execution Error", 16)
        try {
            FileAppend("`n`n=== ERROR ===`n" err.Message "`n", permanentLogFile, "UTF-8")
        }
        return
    }

    ; Parse results
    downloadSuccess := (exitCode = 0)
    videosDownloaded := 0
    errorMessages := []
    warningMessages := []
    downloadedFiles := []

    try {
        ; Read the log file if it exists
        if FileExist(permanentLogFile) {
            logContent := FileRead(permanentLogFile, "UTF-8")
        } else if FileExist(logFile) {
            logContent := FileRead(logFile)
        } else {
            logContent := ""
        }

        ; Extract downloaded filenames - look for FINAL output files only
        loop parse, logContent, "`n", "`r" {
            line := Trim(A_LoopField)

            ; Only count final merged/converted files, not intermediate .webm files
            if InStr(line, "[Merger] Merging formats into") {
                if RegExMatch(line, 'into "(.+?)"', &match) {
                    finalFile := match[1]
                    ; Only add if it's the final format (mp4 or mp3)
                    if (InStr(finalFile, ".mp4") || InStr(finalFile, ".mp3")) {
                        downloadedFiles.Push(finalFile)
                        videosDownloaded++
                    }
                }
            }
            else if InStr(line, "[ExtractAudio] Destination:") {
                if RegExMatch(line, "Destination: (.+)$", &match) {
                    finalFile := Trim(match[1])
                    ; Only add mp3 files
                    if InStr(finalFile, ".mp3") {
                        downloadedFiles.Push(finalFile)
                        videosDownloaded++
                    }
                }
            }
            else if InStr(line, "has already been downloaded") {
                if RegExMatch(line, '\[download\] (.+?) has already been downloaded', &match) {
                    finalFile := Trim(match[1])
                    ; Only count final format files
                    if (InStr(finalFile, ".mp4") || InStr(finalFile, ".mp3")) {
                        downloadedFiles.Push(finalFile)
                        videosDownloaded++
                    }
                }
            }
            ; Alternative: Look for final download completion
            else if InStr(line, "Deleting original file") {
                videosDownloaded++
            }

            if InStr(line, "ERROR:") {
                errorMsg := RegExReplace(line, "^.*ERROR:\s*", "")
                if (errorMsg != "" && errorMsg != line)
                    errorMessages.Push(errorMsg)
            }

            if InStr(line, "WARNING:") {
                warnMsg := RegExReplace(line, "^.*WARNING:\s*", "")
                ; Filter out common non-issue warnings - expanded list
                skipWarning := false
                skipWarning := skipWarning || InStr(warnMsg, "unable to download video info webpage")
                skipWarning := skipWarning || InStr(warnMsg, "Skipping player responses from android clients")
                skipWarning := skipWarning || InStr(warnMsg, "nsig extraction failed")
                skipWarning := skipWarning || InStr(warnMsg, "Signature extraction failed")
                skipWarning := skipWarning || InStr(warnMsg, "Falling back to generic n function search")
                skipWarning := skipWarning || (InStr(warnMsg, "extractor returned") && InStr(warnMsg, "Some web"))
                skipWarning := skipWarning || InStr(warnMsg, "client https formats have been skipped")
                skipWarning := skipWarning || InStr(warnMsg, "are missing a url")
                skipWarning := skipWarning || InStr(warnMsg, "YouTube is forcing SABR streaming")
                skipWarning := skipWarning || InStr(warnMsg, "github.com/yt-dlp/yt-dlp/issues")

                if (warnMsg != "" && warnMsg != line && !skipWarning)
                    warningMessages.Push(warnMsg)
            }
        }

        ; If we still have 0 count, search for actual files in the save directory
        if (videosDownloaded = 0) {
            try {
                ; Count actual mp4/mp3 files in the save directory
                loop files, SavePath "\*.*", "R" {
                    ext := SubStr(A_LoopFileName, -3)
                    if (ext = ".mp4" || ext = ".mp3") {
                        ; Check if file was modified in the last 5 minutes (recently downloaded)
                        fileTime := FileGetTime(A_LoopFileFullPath, "M")
                        currentTime := A_Now
                        timeDiff := DateDiff(currentTime, fileTime, "Minutes")

                        if (timeDiff <= 5) {
                            downloadedFiles.Push(A_LoopFileFullPath)
                            videosDownloaded++
                        }
                    }
                }
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

        ; Delete temp log file (keep permanent log)
        try {
            FileDelete(logFile)
        } catch {
            ; If immediate deletion fails, try delayed deletion
            try {
                Sleep(500)
                FileDelete(logFile)
            } catch {
                ; Still failed - that's okay, we have the permanent log
            }
        }
    } catch as err {
        ; Failed to parse - that's okay
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

    ; Add log file location to message
    logFileMsg := "`n`nLog saved: " permanentLogFile

    hasError := (errorMessages.Length > 0)

    ; Show completion message with Open Folder and Open File buttons
    if (downloadSuccess && !hasError) {
        if (isChannel) {
            notifMsg := channelVideoCount " video(s) downloaded from channel!" filesText warningText "`n`nSaved to: " SavePath logFileMsg
        } else if (downloadWholePlaylist) {
            contentType := (formatChoice = "mp3") ? "audio file(s)" : "video(s)"
            notifMsg := videosDownloaded " " contentType " downloaded from playlist!" filesText warningText "`n`nSaved to: " SavePath logFileMsg
        } else {
            contentType := (formatChoice = "mp3") ? "audio" : "video"
            notifMsg := "Your " contentType " has been downloaded successfully!" filesText warningText "`n`nSaved to: " SavePath logFileMsg
        }

        ; Create custom GUI with two buttons
        completionGui := Gui("+AlwaysOnTop", "Download Complete")
        completionGui.SetFont("s10")
        completionGui.Add("Text", "w500", notifMsg)

        ; Button layout - maintain spacing with invisible spacer
        completionGui.Add("Text", "xm w150 h35", "")
        btnOpenFolder := completionGui.Add("Button", "x+10 yp w150 h35 Default", "Open Folder")
        btnClose := completionGui.Add("Button", "x+10 yp w150 h35", "Close")

        userAction := ""

        btnOpenFolder.OnEvent("Click", (*) => (userAction := "folder", completionGui.Destroy()))
        btnClose.OnEvent("Click", (*) => (userAction := "close", completionGui.Destroy()))
        completionGui.OnEvent("Close", (*) => (userAction := "close", completionGui.Destroy()))

        completionGui.Show()
        WinWaitClose("ahk_id " completionGui.Hwnd)

        if (userAction = "folder") {
            OpenFolderAndSelectFile(SavePath, downloadedFiles)
        }
    } else {
        if (downloadWholePlaylist && videosDownloaded > 0) {
            MsgBox("Download was interrupted!`n`nOnly " videosDownloaded " video(s) were downloaded." errorText,
                "Download Incomplete", 48)
        } else if (videosDownloaded > 0 && !hasError) {
            contentType := (formatChoice = "mp3") ? "audio file(s)" : "video(s)"

            ; Create custom GUI for warning completion
            warningGui := Gui("+AlwaysOnTop", "Download Warning")
            warningGui.SetFont("s10")
            warningGui.Add("Text", "w500", "Download completed with warnings.`n`n" videosDownloaded " " contentType " were downloaded." warningText logFileMsg
            )

            ; Button layout - maintain spacing with invisible spacer
            warningGui.Add("Text", "xm w150 h35", "")
            btnOpenFolderW := warningGui.Add("Button", "x+10 yp w150 h35 Default", "Open Folder")
            btnCloseW := warningGui.Add("Button", "x+10 yp w150 h35", "Close")

            userActionW := ""

            btnOpenFolderW.OnEvent("Click", (*) => (userActionW := "folder", warningGui.Destroy()))
            btnCloseW.OnEvent("Click", (*) => (userActionW := "close", warningGui.Destroy()))
            warningGui.OnEvent("Close", (*) => (userActionW := "close", warningGui.Destroy()))

            warningGui.Show()
            WinWaitClose("ahk_id " warningGui.Hwnd)

            if (userActionW = "folder") {
                OpenFolderAndSelectFile(SavePath, downloadedFiles)
            }
        } else {
            MsgBox("Download failed!" errorText "`n`nCommon solutions:`n• Check your internet connection`n• Verify the video URL is valid`n• Check if video is region-locked or private`n• Ensure FFmpeg is installed correctly`n• Try a different quality setting" logFileMsg,
                "Download Failed", 16)
        }
    }
}

; Function to get or select download location with memory
GetDownloadLocation(formatType := "mp4", Config := "") {
    ; Try to get format-specific last path from config
    lastPath := ""

    if (IsObject(Config)) {
        if (formatType = "mp3" && Config.Has("mp3_path")) {
            lastPath := Config["mp3_path"]
        } else if (formatType = "mp4" && Config.Has("mp4_path")) {
            lastPath := Config["mp4_path"]
        }
    }

    ; If no saved path or path doesn't exist, use Downloads folder
    if (lastPath = "" || !DirExist(lastPath)) {
        lastPath := A_MyDocuments "\..\Downloads"
        try {
            loop files, lastPath, "D" {
                lastPath := A_LoopFileFullPath
                break
            }
        } catch {
            lastPath := A_MyDocuments
        }
    }

    ; Create modern, consistent GUI for location selection
    locationGui := Gui("+AlwaysOnTop", "Select Download Location")
    locationGui.SetFont("s10")

    ; Header with format info
    formatName := (formatType = "mp3") ? "MP3 (Audio)" : "MP4 (Video)"
    locationGui.Add("Text", "w400", "Choose where to save your " formatName " file")

    ; Show current/last used path
    locationGui.Add("GroupBox", "xm w420 h80", "Current Selection")
    currentPathText := locationGui.Add("Text", "xm+15 yp+25 w390", lastPath)

    ; Two main buttons
    btnBrowse := locationGui.Add("Button", "xm w200 h40 Default", "Browse for Folder...")
    btnUseLast := locationGui.Add("Button", "x+20 yp w200 h40", "Use This Location")

    ; Cancel button
    btnCancel := locationGui.Add("Button", "xm w420 h35", "Cancel")

    selectedPath := lastPath
    userChoice := ""

    ; Browse button - opens folder selector
    btnBrowse.OnEvent("Click", (*) => BrowseForFolderNew(locationGui, currentPathText, &selectedPath))

    ; Use last location button
    btnUseLast.OnEvent("Click", (*) => (selectedPath := currentPathText.Value, userChoice := "ok", locationGui.Destroy()))

    ; Cancel button
    btnCancel.OnEvent("Click", (*) => (userChoice := "cancel", locationGui.Destroy()))
    locationGui.OnEvent("Close", (*) => (userChoice := "cancel", locationGui.Destroy()))

    locationGui.Show()
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

    return selectedPath
}

; Helper function for folder browser using Windows Explorer dialog
BrowseForFolderNew(parentGui, textControl, &pathVar) {
    ; Get the GUI handle before opening dialog
    guiHwnd := parentGui.Hwnd

    ; Temporarily hide the GUI to prevent z-order issues
    WinHide("ahk_id " guiHwnd)

    ; Use Windows folder selection dialog (modern style with folder tree)
    selectedFolder := DirSelect("*" textControl.Value, 3, "Select Download Folder")

    ; Show the GUI again
    WinShow("ahk_id " guiHwnd)
    WinActivate("ahk_id " guiHwnd)

    if (selectedFolder != "") {
        textControl.Value := selectedFolder
        pathVar := selectedFolder
    }
}

; Helper function to open folder and select file
OpenFolderAndSelectFile(folderPath, filesList) {
    ; Check if an Explorer window is already open to this path
    targetPath := folderPath
    windowFound := false

    ; Try to find an existing Explorer window with this path
    for window in ComObject("Shell.Application").Windows {
        try {
            ; Get the folder path of the window
            windowPath := window.Document.Folder.Self.Path

            ; Normalize paths for comparison (remove trailing slashes)
            windowPath := RTrim(windowPath, "\")
            targetPath := RTrim(targetPath, "\")

            if (windowPath = targetPath) {
                ; Found the window - activate it
                try {
                    window.Document.SelectItem(filesList.Length > 0 ? filesList[1] : "", 1 + 4 + 8)
                    WinActivate("ahk_id " window.HWND)
                    windowFound := true
                    break
                }
            }
        }
    }

    ; If no existing window found, open a new one
    if (!windowFound) {
        if (filesList.Length > 0) {
            firstFile := filesList[1]

            ; Check if file exists as-is
            if !FileExist(firstFile) && !InStr(firstFile, ":\") {
                firstFile := folderPath "\" firstFile
            }

            if FileExist(firstFile) {
                try {
                    Run('explorer.exe /select,"' firstFile '"')
                } catch {
                    Run('explorer.exe "' folderPath '"')
                }
            } else {
                Run('explorer.exe "' folderPath '"')
            }
        } else {
            Run('explorer.exe "' folderPath '"')
        }
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
        result := MsgBox("yt-dlp is not installed!`n`nWould you like to install it now?", "yt-dlp Not Installed", 4 +
            48)
        if (result = "Yes") {
            toolsToDownload.Push("yt-dlp")
        }
    } else {
        ; Get current version and check for updates (silently in background)
        try {
            currentVersion := GetCurrentYtDlpVersion()
            latestVersion := GetLatestYtDlpVersion()

            if (latestVersion != "" && currentVersion != "" && CompareVersions(currentVersion, latestVersion) < 0) {
                result := MsgBox("A newer version of yt-dlp is available!`n`nInstalled: " currentVersion "`nLatest: " latestVersion "`n`nWould you like to install the update?",
                    "yt-dlp Update Available", 4 + 64)
                if (result = "Yes") {
                    toolsToDownload.Push("yt-dlp")
                }
            }
        } catch as err {
            ; Silent fail - don't show errors during background check
        }
    }

    ; Always check FFmpeg (detect, check version, offer update)
    ffmpegInfo := GetFFmpegLocation()
    if !ffmpegInfo["found"] {
        ; FFmpeg not found - offer to download
        result := MsgBox(
            "FFmpeg is not installed!`n`nFFmpeg is required to merge video and audio for MP4 downloads.`n`nWould you like to install it now?",
            "FFmpeg Not Installed", 4 + 48)
        if (result = "Yes") {
            toolsToDownload.Push("ffmpeg")
        }
    } else {
        ; FFmpeg exists - check for updates (silently in background)
        try {
            currentFFmpegVersion := GetCurrentFFmpegVersion(ffmpegInfo["location"])
            latestFFmpegVersion := GetLatestFFmpegVersion()

            ; Only compare if both versions are valid
            if (latestFFmpegVersion != "" && currentFFmpegVersion != "") {
                ; Extract comparable version numbers (remove build info)
                currentClean := RegExReplace(currentFFmpegVersion, "^[Nn]-", "")
                latestClean := RegExReplace(latestFFmpegVersion, "^[Nn]-", "")

                ; Only prompt if versions are actually different (not just build numbers)
                if (currentClean != latestClean && CompareVersions(currentFFmpegVersion, latestFFmpegVersion) < 0) {
                    result := MsgBox("A newer version of FFmpeg is available!`n`nInstalled: " currentFFmpegVersion "`nLatest: " latestFFmpegVersion "`n`nWould you like to install the update?",
                        "FFmpeg Update Available", 4 + 64)
                    if (result = "Yes") {
                        toolsToDownload.Push("ffmpeg")
                    }
                }
            }
        } catch as err {
            ; Silent fail - don't show errors during background check
        }
    }

    ; Download all missing/outdated tools together
    if (toolsToDownload.Length > 0) {
        DownloadTools(toolsToDownload)
    }
}

; Function to compare version strings
; Returns: -1 if v1 < v2, 0 if equal, 1 if v1 > v2
CompareVersions(v1, v2) {
    ; Remove 'v' prefix if present
    v1 := RegExReplace(v1, "^[vV]", "")
    v2 := RegExReplace(v2, "^[vV]", "")

    ; Handle date-based versions (YYYY.MM.DD format)
    if (RegExMatch(v1, "^\d{4}\.\d{2}\.\d{2}") && RegExMatch(v2, "^\d{4}\.\d{2}\.\d{2}")) {
        ; Convert date format to comparable number
        v1Num := RegExReplace(v1, "[\.]", "")
        v2Num := RegExReplace(v2, "[\.]", "")

        v1Num := SubStr(v1Num, 1, 8)
        v2Num := SubStr(v2Num, 1, 8)

        if (Integer(v1Num) < Integer(v2Num))
            return -1
        else if (Integer(v1Num) > Integer(v2Num))
            return 1
        else
            return 0
    }

    ; Handle N-xxxxx format (FFmpeg nightly builds)
    m1 := ""
    m2 := ""
    if (RegExMatch(v1, "^[Nn]-(\d+)", &m1) && RegExMatch(v2, "^[Nn]-(\d+)", &m2)) {
        n1 := Integer(m1[1])
        n2 := Integer(m2[1])

        if (n1 < n2)
            return -1
        else if (n1 > n2)
            return 1
        else
            return 0
    }

    ; Standard semantic versioning (X.Y.Z)
    parts1 := StrSplit(v1, ".")
    parts2 := StrSplit(v2, ".")

    ; Compare each part
    maxLen := (parts1.Length > parts2.Length) ? parts1.Length : parts2.Length

    loop maxLen {
        val1 := (A_Index <= parts1.Length) ? Integer(RegExReplace(parts1[A_Index], "\D.*$", "")) : 0
        val2 := (A_Index <= parts2.Length) ? Integer(RegExReplace(parts2[A_Index], "\D.*$", "")) : 0

        if (val1 < val2)
            return -1
        else if (val1 > val2)
            return 1
    }

    return 0
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
