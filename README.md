# Windows Debloat

## EXCLUSIVE: Microsoft Gives 11-Year-Olds Full Control of OS Design, Sources Confirm

*"We wanted a fresh perspective," says exec who has since resigned*

---

**REDMOND, WA** — In what industry analysts are calling "the most expensive mistake since Microsoft Bob," internal documents obtained by this publication reveal that Windows 11 was designed primarily by a focus group of children who, when asked what they wanted from an operating system, said: "more stuff on the screen" and "can it show me TikTok."

The results speak for themselves.

Boot up a fresh Windows 11 installation today and you will be greeted by: a Candy Crush invite, a weather widget you didn't ask for, a news feed curated by an algorithm that has decided you are interested in celebrity gossip and sponsored content, a Bing search bar that also searches the web when you are clearly looking for a local file, a Teams icon you cannot explain, a Copilot button that appears to serve no purpose other than to intercept your clicks, and — in a particularly bold move — advertisements in the Start menu itself.

The Start menu. The *Start menu*.

---

### "We're Helping"

Microsoft representatives, when reached for comment, insisted that all of this is *helpful*. The pre-installed copy of Spotify is helpful. The Facebook app is helpful. The Candy Crush Saga, Candy Crush Friends, Candy Crush Soda, and Farm Heroes Saga — all installed without consent on a machine that cost you over a thousand dollars — are, apparently, also helpful.

"Suggested content," the company calls it. In less diplomatic circles, it is called advertising. The distinction, sources say, is largely philosophical.

Meanwhile, Windows has been quietly running a scheduled task called the "Customer Experience Improvement Program" that phones home while you sleep. It runs another task called a "Compatibility Appraiser." And another. And another. At last count, this publication identified sixteen such tasks running in the background of a factory-fresh installation, all of them sending data to Microsoft servers, none of them disclosed at the point of purchase.

---

### The Taskbar: A Study in Chaos

Central to the Windows 11 experience is the taskbar, which has been described by users as "a ransom note in app form."

In the default configuration it contains, from left to right: a Start button (moved to the centre, for reasons that remain unclear), a Search bar (that searches Bing), a Task View button (that almost nobody uses), a Widgets button (that opens a news feed), a Chat/Teams icon (for the Microsoft Teams product you did not purchase), and a Copilot button (for the AI assistant that will helpfully summarise content from other tabs in your browser, which is not something you asked for).

Somewhere at the far right, almost as an afterthought, are the actual system indicators: clock, volume, network. The things you actually need.

The clock, incidentally, does not show seconds by default, because Microsoft decided that knowing what second it is falls outside the scope of a personal computer.

---

### Right-Click Considered Harmful

In what engineers have privately described as "a decision," Windows 11 replaced the classic right-click context menu with a simplified version that hides most options behind a link labelled "Show more options." This link opens the original menu, which is exactly what you wanted in the first place.

The number of clicks required to perform common file operations has therefore doubled. Microsoft has described this as "a cleaner experience."

---

### The Telemetry

Experts in the field estimate that a standard Windows 11 installation reports home on the following topics, among others: which applications you launch, how often you launch them, what you type (via "inking and typing personalisation"), your location (via the Geolocation Service), your device name, your advertising ID, and whatever the "Connected User Experiences and Telemetry" service (`DiagTrack`) considers relevant on any given Tuesday.

There is also a service called `dmwappushservice`, whose official description is "WAP Push Message Routing." No further questions were taken.

---

### Enter: `precious.ps1`

This repository contains one script. It is called `precious.ps1` because it merges everything into a single, definitive tool — the One Debloat Script to Rule Them All.

It scans your system, shows you exactly what it intends to do, asks permission, and then does it. A log file is written to your Desktop. A system restore point is created before any changes are made. A dry-run mode is available for the cautious.

**What it covers:**

- **Bloatware** — removes Microsoft's full catalogue of Bing apps, Cortana, Teams (consumer), Clipchamp, Phone Link, Groove Music, Movies & TV, Solitaire, and the rest. Also removes third-party preinstalls: Candy Crush (and its variants), TikTok, Facebook, Spotify, Amazon, Disney+, Duolingo, and Pandora.
- **ASUS machines** — uninstalls approximately thirty separate ASUS applications, services, scheduled tasks, and startup entries, which ASUS has installed in the manner of a houseguest who has quietly moved all their belongings into your spare room and begun receiving mail. Armoury Crate, MyASUS, ROG Live Service, Aura Sync, GlideX, ScreenXpert, and more.
- **Printer bloatware** — removes HP Smart, Canon Inkjet, Epson Software, and similar Store and Win32 apps that printer manufacturers bundle as if the driver alone wasn't enough.
- **NVIDIA telemetry** — uninstalls the NVIDIA Telemetry Client and disables `NvTelemetryContainer`.
- **Microsoft Office** — uninstalls both Click-to-Run (M365 / Office 2016+) and legacy MSI-based installs, if present.
- **OneDrive** — full uninstall, removal from Explorer sidebar, and policy keys to prevent it reinstalling itself.
- **Telemetry & privacy** — disables data collection, advertising ID, activity history, app launch tracking, inking/typing personalisation, location tracking, CEIP, speech data collection, Find My Device, and clipboard cloud sync. Also opts out of PowerShell and .NET CLI telemetry via machine-level environment variables.
- **Cortana & search** — removes Bing from the Start menu search bar, disables Cortana, disables web search suggestions.
- **Windows Copilot & Recall** — disables Copilot at both user and machine policy level, removes the taskbar button, and turns off Windows Recall (the feature that screenshots your screen every few seconds and stores it locally, which someone apparently thought was a good idea).
- **Services** — disables DiagTrack, dmwappushservice, SysMain, WSearch, Xbox Live services, Windows Error Reporting, Fax, File History, Windows Insider, WMP Network Sharing, Geolocation, Telephony, Diagnostic services, and Connected Devices Platform.
- **Scheduled tasks** — disables sixteen Microsoft telemetry tasks including the Customer Experience Improvement Program suite, the Compatibility Appraiser, disk diagnostic data collectors, and feedback clients.
- **Edge** — suppresses the first-run wizard, disables the shopping assistant, rewards programme, Bing Chat on new tab, Copilot integration, sidebar, recommendations, forced sync, auto sign-in, and the nag to make Edge your default browser. Also prevents Edge from creating a desktop shortcut.
- **Windows Update** — prevents auto-restart while you're logged in, disables peer-to-peer delivery optimisation (which uses your upload bandwidth to distribute updates to strangers), and sets sensible active hours.
- **UI & taskbar** — removes the Chat, Task View, Widgets, and Copilot buttons from the taskbar; left-aligns icons; disables search highlights; enables compact Explorer layout; shows file extensions and hidden files; opens Explorer to This PC; disables snap suggestions; shows seconds in the clock; disables Aero Shake; clears recent files and jump lists.
- **Start menu** — hides the Recommended section, disables AI recommendations, stops silent app auto-installs, and resets the pinned tile layout to a clean state.
- **Visual defaults** — dark mode, no transparency, no accent colour on title bars, neutral dark-grey accent, Details view in Explorer, no "- Shortcut" suffix on shortcuts, no minimize/maximize animations, no Aero Peek.
- **Classic context menu** — restores the full right-click menu instead of the truncated Windows 11 version.
- **App permissions** — force-denies app access to microphone, camera, location, contacts, and notifications at policy level.
- **Miscellaneous** — disables AutoPlay, Windows Ink Workspace, Sticky Keys / Filter Keys / Toggle Keys shortcut prompts, lock screen spotlight ads, and lock screen on resume from sleep.

---

### Usage

Run as Administrator. Review the script first — there is a `$keepPackages` list near the top for things that should survive wildcard removal. Comment out any section you want to keep.

```powershell
# See what would change without doing anything
.\precious.ps1 -DryRunOnly

# Apply all changes (will ask for confirmation)
.\precious.ps1
```

A log file is written to your Desktop. A reboot is recommended when done.

---

### What Is Kept

Calculator. Notepad. Photos. Classic Paint. Camera. Terminal. The Windows Store. Screen Sketch. The codec extensions. The things you actually use.

Windows Defender is not disabled — only its notification noise is reduced. SmartScreen UI prompts are suppressed, not the underlying engine. Xbox game overlay components are retained because they are used by non-Xbox games.

---

### A Note on Responsibility

You purchased a computer. This script returns it to you.

A restore point is created automatically before any changes. The worst-case outcome is a Windows machine that looks like Windows 10, which millions of people used without incident for a decade. If something goes wrong, open System Restore, select the "Pre-Precious-Debloat" point, and proceed as if none of this happened.
