; AHK v2 File Renamer Script
; Renames files in Folder 1 based on names from Folder 2

#Requires AutoHotkey v2.0

; Create GUI
MyGui := Gui(, "File Renamer")
MyGui.SetFont("s10")
MyGui.BackColor := "F0F0F0"
MyGui.MarginX := 15
MyGui.MarginY := 15

; Folder 1 Section
MyGui.Add("GroupBox", "xm ym w550 h70", "Folder 1: Files to be Renamed")
MyGui.Add("Text", "xm+15 ym+25 w50 h20 +0x200", "Path:")
Folder1Edit := MyGui.Add("Edit", "x+10 yp-3 w350 h23 ReadOnly vFolder1 Background")
Folder1Btn := MyGui.Add("Button", "x+10 yp-2 w90 h28", "Browse...")
Folder1Btn.OnEvent("Click", SelectFolder1)

; Folder 2 Section
MyGui.Add("GroupBox", "xm y+15 w550 h70", "Folder 2: Source of New Names")
MyGui.Add("Text", "xm+15 yp+25 w50 h20 +0x200", "Path:")
Folder2Edit := MyGui.Add("Edit", "x+10 yp-3 w350 h23 ReadOnly vFolder2 Background")
Folder2Btn := MyGui.Add("Button", "x+10 yp-2 w90 h28", "Browse...")
Folder2Btn.OnEvent("Click", SelectFolder2)

; Options Section
MyGui.Add("GroupBox", "xm y+15 w550 h60", "Options")
MyGui.Add("Text", "xm+15 yp+25 w70 h20 +0x200", "Sort files by:")
SortChoice := MyGui.Add("DropDownList", "x+10 yp-3 w150 Choose1", ["Name", "Date Modified", "Date Created"])
SortChoice.OnEvent("Change", (*) => AutoPreview())

KeepExtensionCB := MyGui.Add("Checkbox", "x+20 yp+3 Checked", "Keep original file extensions")
KeepExtensionCB.OnEvent("Click", (*) => AutoPreview())

; Preview Section
MyGui.Add("GroupBox", "xm y+15 w550 h230", "Preview")
PreviewList := MyGui.Add("ListView", "xm+10 yp+20 w530 h195 Grid", ["Original Name", "New Name"])
PreviewList.ModifyCol(1, 260)
PreviewList.ModifyCol(2, 260)

; Buttons
RenameBtn := MyGui.Add("Button", "xm y+15 w180 h35 Default", "Rename Files")
RenameBtn.OnEvent("Click", RenameFiles)

ExitBtn := MyGui.Add("Button", "x+20 yp w180 h35", "Exit")
ExitBtn.OnEvent("Click", (*) => ExitApp())

; Status bar
StatusText := MyGui.Add("Text", "xm y+10 w550 h20 +0x200 Background", "Ready. Select both folders to begin.")

; Show GUI
MyGui.Show("w580 h560")

; Global variables
Folder1Path := ""
Folder2Path := ""

; Function to select Folder 1
SelectFolder1(*) {
    global Folder1Path, Folder1Edit, StatusText
    Folder1Path := DirSelect("", 3, "Select Folder 1 (Files to rename)")
    if (Folder1Path != "") {
        Folder1Edit.Value := Folder1Path
        StatusText.Value := "Folder 1 selected: " . Folder1Path
        AutoPreview()
    }
}

; Function to select Folder 2
SelectFolder2(*) {
    global Folder2Path, Folder2Edit, StatusText
    Folder2Path := DirSelect("", 3, "Select Folder 2 (Source of new names)")
    if (Folder2Path != "") {
        Folder2Edit.Value := Folder2Path
        StatusText.Value := "Folder 2 selected: " . Folder2Path
        AutoPreview()
    }
}

; Function to get files from folder sorted by choice
GetSortedFiles(folderPath, sortBy) {
    files := []

    loop files, folderPath . "\*.*", "F" {
        fileInfo := {
            Path: A_LoopFilePath,
            Name: A_LoopFileName,
            Modified: A_LoopFileTimeModified,
            Created: A_LoopFileTimeCreated
        }
        files.Push(fileInfo)
    }

    ; Sort based on selection
    if (sortBy = "Date Modified") {
        files := SortByModified(files)
    } else if (sortBy = "Date Created") {
        files := SortByCreated(files)
    } else {
        files := SortByName(files)
    }

    return files
}

; Sorting functions
SortByName(files) {
    n := files.Length
    loop n - 1 {
        i := A_Index
        loop n - i {
            j := A_Index + i
            if (StrCompare(files[i].Name, files[j].Name, true) > 0) {
                temp := files[i]
                files[i] := files[j]
                files[j] := temp
            }
        }
    }
    return files
}

SortByModified(files) {
    n := files.Length
    loop n - 1 {
        i := A_Index
        loop n - i {
            j := A_Index + i
            if (files[i].Modified > files[j].Modified) {
                temp := files[i]
                files[i] := files[j]
                files[j] := temp
            }
        }
    }
    return files
}

SortByCreated(files) {
    n := files.Length
    loop n - 1 {
        i := A_Index
        loop n - i {
            j := A_Index + i
            if (files[i].Created > files[j].Created) {
                temp := files[i]
                files[i] := files[j]
                files[j] := temp
            }
        }
    }
    return files
}

; Preview changes
PreviewChanges(*) {
    global Folder1Path, Folder2Path, PreviewList, SortChoice, KeepExtensionCB, StatusText

    if (Folder1Path = "" || Folder2Path = "") {
        return
    }

    PreviewList.Delete()

    sortBy := SortChoice.Text
    folder1Files := GetSortedFiles(Folder1Path, sortBy)
    folder2Files := GetSortedFiles(Folder2Path, sortBy)

    if (folder1Files.Length = 0) {
        StatusText.Value := "No files found in Folder 1!"
        return
    }

    if (folder2Files.Length = 0) {
        StatusText.Value := "No files found in Folder 2!"
        return
    }

    ; Check if file counts match
    if (folder1Files.Length != folder2Files.Length) {
        StatusText.Value := "Error: Folder 1 has " . folder1Files.Length . " files, Folder 2 has " . folder2Files.Length .
            " files. Counts must match!"
        MsgBox("File count mismatch!`n`nFolder 1: " . folder1Files.Length . " files`nFolder 2: " . folder2Files.Length .
            " files`n`nBoth folders must have the same number of files.", "Error", 48)
        return
    }

    matchCount := Min(folder1Files.Length, folder2Files.Length)

    loop matchCount {
        oldName := folder1Files[A_Index].Name

        if (KeepExtensionCB.Value) {
            nameNoExt := ""
            ext := ""
            SplitPath(folder2Files[A_Index].Name, , , , &nameNoExt)
            SplitPath(oldName, , , &ext)
            newName := nameNoExt . "." . ext
        } else {
            newName := folder2Files[A_Index].Name
        }

        PreviewList.Add("", oldName, newName)
    }

    StatusText.Value := "Preview ready. " . matchCount . " file(s) will be renamed."
}

; Auto preview function
AutoPreview(*) {
    PreviewChanges()
}

; Rename files
RenameFiles(*) {
    global Folder1Path, Folder2Path, SortChoice, KeepExtensionCB, StatusText, PreviewList

    if (Folder1Path = "" || Folder2Path = "") {
        MsgBox("Please select both folders first!", "Error", 48)
        return
    }

    sortBy := SortChoice.Text
    folder1Files := GetSortedFiles(Folder1Path, sortBy)
    folder2Files := GetSortedFiles(Folder2Path, sortBy)

    ; Check if file counts match
    if (folder1Files.Length != folder2Files.Length) {
        MsgBox("File count mismatch!`n`nFolder 1: " . folder1Files.Length . " files`nFolder 2: " . folder2Files.Length .
            " files`n`nBoth folders must have the same number of files.", "Error", 48)
        return
    }

    result := MsgBox("Are you sure you want to rename the files? This cannot be undone!", "Confirm", 4 + 48)
    if (result = "No") {
        return
    }

    sortBy := SortChoice.Text
    folder1Files := GetSortedFiles(Folder1Path, sortBy)
    folder2Files := GetSortedFiles(Folder2Path, sortBy)

    matchCount := Min(folder1Files.Length, folder2Files.Length)
    successCount := 0
    errorCount := 0

    loop matchCount {
        oldPath := folder1Files[A_Index].Path

        if (KeepExtensionCB.Value) {
            nameNoExt := ""
            ext := ""
            SplitPath(folder2Files[A_Index].Name, , , , &nameNoExt)
            SplitPath(folder1Files[A_Index].Name, , , &ext)
            newName := nameNoExt . "." . ext
        } else {
            newName := folder2Files[A_Index].Name
        }

        newPath := Folder1Path . "\" . newName

        try {
            FileMove(oldPath, newPath, 0)
            successCount++
        } catch {
            errorCount++
        }
    }

    StatusText.Value := "Done! " . successCount . " files renamed, " . errorCount . " errors."
    MsgBox("Renaming complete!`n`nSuccess: " . successCount . "`nErrors: " . errorCount, "Complete", 64)

    ; Refresh preview
    AutoPreview()
}

Min(a, b) {
    return (a < b) ? a : b
}

Max(a, b) {
    return (a > b) ? a : b
}
