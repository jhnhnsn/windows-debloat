# Comparison: debloat-windows.ps1 vs debloat-win11.ps1

## Summary

| Feature | debloat-windows.ps1 | debloat-win11.ps1 |
|---------|--------------------|--------------------|
| Architecture | Sequential, runs top-to-bottom | Action-based (Detect + Apply closures) |
| Dry-run mode | No | Yes (`-DryRunOnly` flag) |
| File logging | No | Yes (timestamped log on Desktop) |
| User confirmation | No | Yes (shows pending changes, asks before applying) |
| App keep-list | No | Yes (protects Store, Calculator, Notepad, etc.) |
| Wildcard app removal | No | Yes |

---

## Architecture

**debloat-windows.ps1** runs sequentially: each section executes immediately in order with no opportunity to preview or skip.

**debloat-win11.ps1** uses a two-phase approach:
1. **Scan phase**: builds an `$actions` array of `{Category, Description, Detect, Apply}` hashtables, runs all `Detect` scriptblocks, and lists what needs to change.
2. **Apply phase**: asks for confirmation, then runs only the `Apply` blocks for pending items.

This makes `debloat-win11.ps1` idempotent — re-running it only applies what has drifted.

---

## App Removal Differences

**debloat-windows.ps1** uses a static list of ~45 specific package IDs. No wildcards, no keep-list.

**debloat-win11.ps1** uses:
- A specific list of ~35 modern/updated package IDs (includes `Microsoft.549981C3F5F10` for Cortana, `Microsoft.Copilot`, `Microsoft.GamingApp`, `Microsoft.BingSearch`, `Microsoft.WidgetsPlatformRuntime`, `MicrosoftWindows.CrossDevice`)
- Wildcard patterns (`*CandyCrush*`, `*TikTok*`, `*DevHome*`, `*WindowsWorkload*`, etc.)
- A **keep-list** that prevents wildcards from removing: Store, Calculator, Notepad, Paint, Photos, Camera, Terminal, DesktopAppInstaller, codec extensions, ScreenSketch, Xbox overlay/identity packages, OneDrive

Apps only in `debloat-windows.ps1`: BingFinance, BingFoodAndDrink, BingHealthAndFitness, BingTravel, BingSports, Messaging, Microsoft3DViewer, MSPaint (Paint 3D), MixedReality.Portal, NetworkSpeedTest, OneConnect, Print3D, SkypeApp, WindowsAlarms, WindowsCamera, WindowsPhone, Xbox.TCUI, XboxApp, XboxGameOverlay, XboxGamingOverlay, XboxIdentityProvider, XboxSpeechToTextOverlay (several of these are Windows 10-era apps no longer present in Win11).

---

## Features Exclusive to debloat-windows.ps1

- **Office uninstall**: Handles both Click-to-Run (`setup.exe /configure`) and legacy MSI installs.
- **OneDrive full uninstall**: Runs `OneDriveSetup.exe /uninstall`, then sets registry policy to block reinstall and removes it from the Explorer sidebar.
- **Privacy: app permissions via policy**: Force-denies microphone, camera, location, contacts, and notification access for all apps (`LetAppsAccess*` = 2).
- **Visual/cosmetic changes**:
  - Forces dark mode (system + apps, both HKCU and HKLM)
  - Restores classic right-click context menu
  - Sets neutral dark-grey accent color (ABGR 0xFF4C4C4C)
  - Disables accent color on taskbar/title bars
  - Enables compact Explorer layout
  - Sets default Explorer view to Details (writes shell bag)
  - Disables Aero Shake
  - Disables AutoPlay
  - Removes "- Shortcut" suffix from new shortcuts
  - Disables taskbar button combining (show full labels)
  - Shows seconds in taskbar clock
- **Restarts Explorer** at end to apply taskbar/shell changes immediately.

---

## Features Exclusive to debloat-win11.ps1

- **ASUS bloatware removal** (comprehensive):
  - Store apps via wildcards (`*MyASUS*`, `*ArmouryCrate*`, `*ROGLiveService*`, etc.)
  - Win32 uninstall via registry (Armoury Crate, GameVisual, GlideX, ScreenXpert, ASUS AI Suite, etc.)
  - ASUS services (15 services: ASUSOptimization, ArmouryCrateSEService, ROG Live, Aura lighting, etc.)
  - ASUS scheduled tasks (all tasks under `\ASUS\` paths)
  - ASUS startup registry entries (Run keys)
- **NVIDIA telemetry removal**: Uninstalls NVIDIA Telemetry Client (Win32), disables `NvTelemetryContainer` service, disables scheduled tasks (NvTmMon, NvTmRep, NvProfile, NvNode).
- **Edge browser hardening** (~20 policies): skips first-run, disables sidebar, shopping assistant, rewards, sign-in prompts, Bing Chat, Copilot, Collections, recommendations, forced sync, auto sign-in, new tab content. Prevents desktop shortcut creation. Disables Edge auto-update scheduled tasks.
- **Windows Update settings**: prevents auto-restart while user is logged in, sets download-and-schedule mode (not auto-install), disables P2P delivery optimization, sets active hours 8 AM–11 PM.
- **Game Bar / DVR**: disables Game DVR capture, Game Bar overlay, auto Game Mode, startup panel.
- **Copilot and Recall**: disables Windows Copilot (user + machine policy), hides Copilot taskbar button, disables Windows Recall (`DisableAIDataAnalysis`, `TurnOffSavingSnapshots`).
- **Windows Ink Workspace**: disables Ink Workspace and suggested apps within it.
- **Clipboard cloud sync**: disables clipboard history and cross-device clipboard sync.
- **Background apps**: globally disables UWP background apps, sets policy (`LetAppsRunInBackground` = 2).
- **OneDrive nags** (without uninstalling): suppresses Known Folder Move prompts and OneDrive ads in Explorer. Keeps OneDrive functional.
- **Printer bloatware**: removes HP, Canon, Epson, Brother, Lexmark, Samsung Store apps and Win32 installers.
- **Recent files / Quick Access**: disables recent files and frequent folders in Quick Access, clears existing recent files and jump lists.
- **PowerShell and .NET CLI telemetry**: sets `POWERSHELL_TELEMETRY_OPTOUT=1` and `DOTNET_CLI_TELEMETRY_OPTOUT=1` as machine-level environment variables.
- **Additional privacy settings**: disables tailored experiences, device name in telemetry, Application Impact Telemetry (AITEnable), CEIP, speech model updates, Find My Device, inking/typing linguistic data collection.
- **Additional services disabled**: DPS (Diagnostic Policy Service), WdiServiceHost, WdiSystemHost, CDPSvc, CDPUserSvc, PcaSvc (Program Compatibility Assistant). Does NOT disable: WSearch, SysMain, XblAuthManager/XblGameSave/XboxNetApiSvc/XboxGipSvc, stisvc, SharedAccess, WerSvc, fhsvc, TapiSrv, icssvc, WMPNetworkSvc (or disables a subset — fewer than the other script).

---

## Services Comparison

| Service | debloat-windows.ps1 | debloat-win11.ps1 |
|---------|--------------------|--------------------|
| DiagTrack | Disabled | Disabled |
| dmwappushservice | Disabled | Disabled |
| SysMain (Superfetch) | Disabled | Disabled |
| WSearch | Disabled | Disabled |
| XblAuthManager | Disabled | Not touched |
| XblGameSave | Disabled | Not touched |
| XboxNetApiSvc | Disabled | Not touched |
| XboxGipSvc | Disabled | Not touched |
| RetailDemo | Disabled | Disabled |
| MapsBroker | Disabled | Disabled |
| lfsvc (Geolocation) | Disabled | Disabled |
| SharedAccess (ICS) | Disabled | Not touched |
| WerSvc | Disabled | Disabled |
| Fax | Disabled | Disabled |
| fhsvc (File History) | Disabled | Not touched |
| wisvc (Insider) | Disabled | Disabled |
| WMPNetworkSvc | Disabled | Disabled |
| icssvc (Mobile Hotspot) | Disabled | Not touched |
| PhoneSvc | Disabled | Disabled |
| TapiSrv (Telephony) | Disabled | Not touched |
| stisvc (WIA scanners) | Disabled | Not touched |
| DPS | Not touched | Disabled |
| WdiServiceHost | Not touched | Disabled |
| WdiSystemHost | Not touched | Disabled |
| CDPSvc | Not touched | Disabled |
| CDPUserSvc | Not touched | Disabled |
| PcaSvc | Not touched | Disabled |

---

## Recommended Use

- **debloat-windows.ps1**: Quick, opinionated, fire-and-forget. Good for a fresh personal install where you want cosmetic changes (dark mode, compact Explorer) applied immediately and Office/OneDrive fully removed.

- **debloat-win11.ps1**: Safer and more systematic. Better for shared/managed machines, ASUS hardware, or when you want to preview changes before committing. Skips cosmetic opinions (no dark mode, no accent color changes). Covers more modern Win11 features (Recall, Copilot, Edge policies, NVIDIA telemetry).
