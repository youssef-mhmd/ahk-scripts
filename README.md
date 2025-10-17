# AHK Scripts Collection

A collection of custom **AutoHotkey v2** scripts designed to automate repetitive tasks, enhance productivity, and streamline multimedia workflows on Windows.

---

## 📂 Repository Contents

### 1. **constantclicking.ahk**
**Description:**  
A minimal auto-clicker that continuously simulates left mouse clicks at a fixed interval.  

**Key Features:**  
- Constant clicking every 10 milliseconds.  
- Toggle activation with `F8`.  
- Adjustable interval for different use cases.  

**Use Case:**  
Ideal for idle games or repetitive mouse tasks.

---

### 2. **minecraft_autoclicker.ahk**
**Description:**  
A specialized auto-clicker designed for **Minecraft**, enabling automated in-game actions while detecting the active Minecraft window.  

**Key Features:**  
- Auto-clicks every 10 seconds only when Minecraft is running.  
- Adjustable click delay.  
- F8 to toggle control.  

**Use Case:**  
Automates mining, building, or combat actions within Minecraft.

---

### 3. **my own script.ahk**
**Description:**  
A personalized all-in-one automation script containing custom shortcuts, hotkeys, and workflow enhancements.  

**Key Features:**  
- Quick app launchers.  
- Window management tools.  
- Miscellaneous quality-of-life shortcuts.  

**Use Case:**  
General Windows productivity improvements tailored to personal workflow.

---

### 4. **multimedia_downloader.ahk**
**Description:**  
An **AutoHotkey v2 GUI tool** for downloading online videos or playlists as MP3 or MP4 files with user-defined settings.  

**Key Features:**  
- Download videos or playlists with format and quality selection.  
- Detects and reports download failures.  
- Displays messages on successful downloads or interruptions.  
- Uses a fixed download directory (modifiable).  
- Playlist recognition and batch handling.  

**Dependencies:**  
- [yt-dlp](https://github.com/yt-dlp/yt-dlp)  
- [ffmpeg](https://ffmpeg.org/download.html)  
(Both must be installed and added to your system PATH. or in the same folder with the script)

---

## ⚙️ Requirements
- **Operating System:** Windows 10 or 11  
- **Runtime:** [AutoHotkey v2](https://www.autohotkey.com/)  
- **Optional Tools:** yt-dlp, ffmpeg (for multimedia downloads)

---

## 🚀 Usage Instructions
1. Clone or download this repository.  
2. Install **AutoHotkey v2**.  
3. Double-click any `.ahk` script to run it.  
4. Edit the script in any text editor to customize hotkeys, intervals, or paths.  
5. To stop a script, right-click the AHK icon in the system tray and choose **Exit**.

---

## 🧩 Tips
- All scripts follow **AutoHotkey v2 syntax**.  
- When combining scripts, ensure `#Requires AutoHotkey v2.0` is declared only once at the top.  
- Scripts can be run simultaneously as long as they don’t share conflicting hotkeys.  

---

## 👤 Author
Developed and maintained by **Youssef Mohamed**.  
For questions, improvements, or contributions, feel free to open an issue or pull request.

