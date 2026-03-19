#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Windows 11 debloat script - removes bloatware, disables telemetry, cleans up services.
.NOTES
    Run as Administrator. Creates a restore point before making changes.
    Safe to run on a fresh install. Review sections and comment out anything you want to keep.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "SilentlyContinue"

function Write-Section($title) {
    Write-Host "`n=== $title ===" -ForegroundColor Cyan
}

function Remove-AppIfPresent($appName) {
    $pkg = Get-AppxPackage -AllUsers -Name $appName
    if ($pkg) {
        Write-Host "  Removing: $appName" -ForegroundColor Yellow
        Remove-AppxPackage -AllUsers -Package $pkg.PackageFullName
    }
    # Also remove provisioned (stops reinstall for new users)
    $prov = Get-AppxProvisionedPackage -Online | Where-Object DisplayName -like $appName
    if ($prov) {
        Remove-AppxProvisionedPackage -Online -PackageName $prov.PackageName | Out-Null
    }
}

function Disable-ServiceSafe($name) {
    $svc = Get-Service -Name $name -ErrorAction SilentlyContinue
    if ($svc) {
        Write-Host "  Disabling service: $name" -ForegroundColor Yellow
        Stop-Service -Name $name -Force
        Set-Service -Name $name -StartupType Disabled
    }
}

function Set-RegistryValue($path, $name, $value, $type = "DWord") {
    if (-not (Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
    Set-ItemProperty -Path $path -Name $name -Value $value -Type $type -Force
}

# ---------------------------------------------------------------------------
Write-Section "Creating System Restore Point"
# ---------------------------------------------------------------------------
Enable-ComputerRestore -Drive "C:\"
Checkpoint-Computer -Description "Before debloat script" -RestorePointType "MODIFY_SETTINGS"
Write-Host "  Restore point created." -ForegroundColor Green

# ---------------------------------------------------------------------------
Write-Section "Removing Built-in Bloatware Apps"
# ---------------------------------------------------------------------------
$appsToRemove = @(
    # Microsoft bloat
    "Microsoft.3DBuilder"
    "Microsoft.BingFinance"
    "Microsoft.BingFoodAndDrink"
    "Microsoft.BingHealthAndFitness"
    "Microsoft.BingMaps"
    "Microsoft.BingNews"
    "Microsoft.BingSports"
    "Microsoft.BingTravel"
    "Microsoft.BingWeather"
    "Microsoft.GetHelp"
    "Microsoft.Getstarted"
    "Microsoft.Messaging"
    "Microsoft.Microsoft3DViewer"
    "Microsoft.MicrosoftOfficeHub"
    "Microsoft.MicrosoftSolitaireCollection"
    "Microsoft.MicrosoftStickyNotes"
    "Microsoft.MixedReality.Portal"
    "Microsoft.MSPaint"           # Paint 3D (classic Paint is separate)
    "Microsoft.NetworkSpeedTest"
    "Microsoft.News"
    "Microsoft.Office.OneNote"
    "Microsoft.OneConnect"
    "Microsoft.People"
    "Microsoft.PowerAutomateDesktop"
    "Microsoft.Print3D"
    "Microsoft.SkypeApp"
    "Microsoft.Teams"
    "Microsoft.Todos"
    "Microsoft.WindowsAlarms"
    "Microsoft.WindowsCamera"
    "Microsoft.windowscommunicationsapps" # Mail & Calendar
    "Microsoft.WindowsFeedbackHub"
    "Microsoft.WindowsMaps"
    "Microsoft.WindowsPhone"
    "Microsoft.WindowsSoundRecorder"
    "Microsoft.Xbox.TCUI"
    "Microsoft.XboxApp"
    "Microsoft.XboxGameOverlay"
    "Microsoft.XboxGamingOverlay"
    "Microsoft.XboxIdentityProvider"
    "Microsoft.XboxSpeechToTextOverlay"
    "Microsoft.YourPhone"              # Phone Link
    "Microsoft.ZuneMusic"              # Groove Music
    "Microsoft.ZuneVideo"              # Movies & TV
    "MicrosoftCorporationII.MicrosoftFamily"
    "MicrosoftCorporationII.QuickAssist"
    "Microsoft.Clipchamp"
    "Microsoft.OutlookForWindows"
    "Microsoft.OneDriveSync"
    # Third-party preinstalls
    "SpotifyAB.SpotifyMusic"
    "king.com.CandyCrushSaga"
    "king.com.CandyCrushFriends"
    "king.com.FarmHeroesSaga"
    "Facebook.Facebook"
    "TikTok.TikTok"
    "BytedancePte.Ltd.TikTok"
    "Amazon.com.Amazon"
    "AmazonVideo.PrimeVideo"
    "Disney.37853D22215B2"
    "Duolingo-LearnLanguagesforFree"
    "EclipseManager"
    "ActiproSoftwareLLC.562882FEEB491"
    "DolbyLaboratories.DolbyAudio"
    "D5EA27B7.Duolingo-LearnLanguagesforFree"
    "PandoraMediaInc.29680B314EFC2"
)

foreach ($app in $appsToRemove) {
    Remove-AppIfPresent $app
}

# ---------------------------------------------------------------------------
Write-Section "Uninstalling Microsoft Office"
# ---------------------------------------------------------------------------
# Handles both Click-to-Run (M365/Office 2016+) and legacy MSI-based installs.

# --- Click-to-Run (most modern Office installs) ---
$c2rSetup = @(
    "$env:ProgramFiles\Common Files\microsoft shared\ClickToRun\setup.exe"
    "${env:ProgramFiles(x86)}\Common Files\microsoft shared\ClickToRun\setup.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1

if ($c2rSetup) {
    Write-Host "  Click-to-Run Office found. Uninstalling..." -ForegroundColor Yellow
    $xmlPath = "$env:TEMP\office-uninstall.xml"
    @'
<Configuration>
  <Remove All="TRUE" />
  <Display Level="None" AcceptEULA="TRUE" />
  <Property Name="FORCEAPPSHUTDOWN" Value="TRUE" />
</Configuration>
'@ | Set-Content -Path $xmlPath -Encoding UTF8
    Start-Process $c2rSetup -ArgumentList "/configure `"$xmlPath`"" -Wait -NoNewWindow
    Remove-Item $xmlPath -Force -ErrorAction SilentlyContinue
    Write-Host "  Click-to-Run uninstall complete." -ForegroundColor Green
} else {
    Write-Host "  No Click-to-Run Office installation found." -ForegroundColor Gray
}

# --- MSI-based Office (Office 2013 and older, some volume licenses) ---
$regPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
)
$officePatterns = 'Microsoft Office|Microsoft 365|Office 16|Office 15|Office 14'
$found = $false
foreach ($path in $regPaths) {
    Get-ItemProperty $path -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName -match $officePatterns -and $_.UninstallString -match 'msiexec' } |
    ForEach-Object {
        $found = $true
        Write-Host "  Uninstalling (MSI): $($_.DisplayName)" -ForegroundColor Yellow
        $guid = ($_.UninstallString -replace '.*(\{[^}]+\}).*', '$1')
        Start-Process msiexec.exe -ArgumentList "/x $guid /qn /norestart REBOOT=ReallySuppress" -Wait -NoNewWindow
    }
}
if (-not $found -and -not $c2rSetup) {
    Write-Host "  No MSI Office products found." -ForegroundColor Gray
}

# ---------------------------------------------------------------------------
Write-Section "Disabling OneDrive"
# ---------------------------------------------------------------------------
Write-Host "  Stopping and uninstalling OneDrive..." -ForegroundColor Yellow
Stop-Process -Name "OneDrive" -Force
Start-Sleep 2
$onedrive = "$env:SYSTEMROOT\System32\OneDriveSetup.exe"
if (-not (Test-Path $onedrive)) { $onedrive = "$env:SYSTEMROOT\SysWOW64\OneDriveSetup.exe" }
if (Test-Path $onedrive) { & $onedrive /uninstall }

# Prevent OneDrive from running / being reinstalled
Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive" "DisableFileSyncNGSC" 1
Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive" "DisableFileSync" 1

# Remove OneDrive from Explorer sidebar
Set-RegistryValue "HKCR:\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}" "System.IsPinnedToNameSpaceTree" 0
Set-RegistryValue "HKCR:\Wow6432Node\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}" "System.IsPinnedToNameSpaceTree" 0

# ---------------------------------------------------------------------------
Write-Section "Disabling Telemetry and Data Collection"
# ---------------------------------------------------------------------------
# Telemetry level: 0 = Security (Enterprise only), 1 = Basic - use 1 on Home/Pro
Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "AllowTelemetry" 0
Set-RegistryValue "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" "AllowTelemetry" 0
Set-RegistryValue "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Policies\DataCollection" "AllowTelemetry" 0

# Disable feedback frequency
Set-RegistryValue "HKCU:\SOFTWARE\Microsoft\Siuf\Rules" "NumberOfSIUFInPeriod" 0
Set-RegistryValue "HKCU:\SOFTWARE\Microsoft\Siuf\Rules" "PeriodInNanoSeconds" 0

# Disable advertising ID
Set-RegistryValue "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo" "Enabled" 0
Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo" "DisabledByGroupPolicy" 1

# Disable activity history / Timeline
Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "EnableActivityFeed" 0
Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "PublishUserActivities" 0
Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "UploadUserActivities" 0

# Disable app launch tracking
Set-RegistryValue "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Start_TrackProgs" 0

# Disable location tracking
Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" "DisableLocation" 1

# Disable inking & typing personalization (sends data to MS)
Set-RegistryValue "HKCU:\SOFTWARE\Microsoft\InputPersonalization" "RestrictImplicitInkCollection" 1
Set-RegistryValue "HKCU:\SOFTWARE\Microsoft\InputPersonalization" "RestrictImplicitTextCollection" 1
Set-RegistryValue "HKCU:\SOFTWARE\Microsoft\Personalization\Settings" "AcceptedPrivacyPolicy" 0

# Disable Cortana
Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" "AllowCortana" 0
Set-RegistryValue "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" "BingSearchEnabled" 0
Set-RegistryValue "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" "CortanaEnabled" 0

# Disable web search in Start menu
Set-RegistryValue "HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer" "DisableSearchBoxSuggestions" 1
Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" "DisableWebSearch" 1
Set-RegistryValue "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" "SearchboxTaskbarMode" 1  # 0=hidden, 1=icon, 2=full

# ---------------------------------------------------------------------------
Write-Section "Disabling Unnecessary Services"
# ---------------------------------------------------------------------------
$servicesToDisable = @(
    "DiagTrack"                    # Connected User Experiences and Telemetry
    "dmwappushservice"             # WAP Push Message Routing (telemetry)
    "SysMain"                      # Superfetch - can cause HDD thrashing; safe to disable on SSD
    "WSearch"                      # Windows Search indexer - disable if you don't use it
    "XblAuthManager"               # Xbox Live Auth
    "XblGameSave"                  # Xbox Live Game Save
    "XboxNetApiSvc"                # Xbox Live Networking
    "XboxGipSvc"                   # Xbox Accessory Management
    "RetailDemo"                   # Retail Demo Service
    "MapsBroker"                   # Downloaded Maps Manager
    "lfsvc"                        # Geolocation Service
    "SharedAccess"                 # Internet Connection Sharing
    "WerSvc"                       # Windows Error Reporting
    "Fax"                          # Fax service
    "fhsvc"                        # File History Service
    "wisvc"                        # Windows Insider Service
    "WMPNetworkSvc"                # Windows Media Player Network Sharing
    "icssvc"                       # Windows Mobile Hotspot Service
    "PhoneSvc"                     # Phone Service
    "TapiSrv"                      # Telephony
    "stisvc"                       # Windows Image Acquisition (scanners/cameras)
)

foreach ($svc in $servicesToDisable) {
    Disable-ServiceSafe $svc
}

# ---------------------------------------------------------------------------
Write-Section "Disabling Scheduled Telemetry Tasks"
# ---------------------------------------------------------------------------
$tasksToDisable = @(
    "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser"
    "\Microsoft\Windows\Application Experience\ProgramDataUpdater"
    "\Microsoft\Windows\Application Experience\StartupAppTask"
    "\Microsoft\Windows\Autochk\Proxy"
    "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator"
    "\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip"
    "\Microsoft\Windows\Customer Experience Improvement Program\KernelCeipTask"
    "\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector"
    "\Microsoft\Windows\Feedback\Siuf\DmClient"
    "\Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload"
    "\Microsoft\Windows\Windows Error Reporting\QueueReporting"
    "\Microsoft\Windows\CloudExperienceHost\CreateObjectTask"
    "\Microsoft\Windows\Maps\MapsToastTask"
    "\Microsoft\Windows\Maps\MapsUpdateTask"
    "\Microsoft\Windows\Clip\License Validation"
    "\Microsoft\Windows\Speech\SpeechModelDownloadTask"
)

foreach ($task in $tasksToDisable) {
    $t = Get-ScheduledTask -TaskPath (Split-Path $task -Parent) -TaskName (Split-Path $task -Leaf) -ErrorAction SilentlyContinue
    if ($t) {
        Write-Host "  Disabling task: $task" -ForegroundColor Yellow
        Disable-ScheduledTask -TaskPath (Split-Path $task -Parent) -TaskName (Split-Path $task -Leaf) | Out-Null
    }
}

# ---------------------------------------------------------------------------
Write-Section "Unpinning All Apps from Start Menu"
# ---------------------------------------------------------------------------
# Windows 11 stores pinned Start menu items in start2.bin per user.
# Deleting it causes Windows to regenerate a minimal default layout on next login.
$startBinPath = "$env:LOCALAPPDATA\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState\start2.bin"
if (Test-Path $startBinPath) {
    # Only back up once - don't overwrite the original backup on subsequent runs
    if (-not (Test-Path "$startBinPath.bak")) {
        Write-Host "  Backing up start2.bin..." -ForegroundColor Yellow
        Copy-Item $startBinPath "$startBinPath.bak" -Force
    } else {
        Write-Host "  Backup already exists, skipping backup." -ForegroundColor Gray
    }
    # Stop the Start menu host so the file isn't locked
    Stop-Process -Name "StartMenuExperienceHost" -Force -ErrorAction SilentlyContinue
    Start-Sleep 1
    Remove-Item $startBinPath -Force
    Write-Host "  Done. Windows will regenerate a clean layout on next login." -ForegroundColor Green
} else {
    Write-Host "  start2.bin not found - already clean or not yet generated." -ForegroundColor Gray
}

# ---------------------------------------------------------------------------
Write-Section "Cleaning Up Start Menu and Taskbar"
# ---------------------------------------------------------------------------
# Remove recommended section from Start menu
Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" "HideRecommendedSection" 1

# Disable suggested content / ads in Start
Set-RegistryValue "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SubscribedContent-338388Enabled" 0
Set-RegistryValue "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SubscribedContent-338389Enabled" 0
Set-RegistryValue "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SubscribedContent-353698Enabled" 0
Set-RegistryValue "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SystemPaneSuggestionsEnabled" 0
Set-RegistryValue "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SoftLandingEnabled" 0
Set-RegistryValue "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "OemPreInstalledAppsEnabled" 0
Set-RegistryValue "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "PreInstalledAppsEnabled" 0
Set-RegistryValue "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SilentInstalledAppsEnabled" 0  # Stop auto-installing apps!

# Remove Chat (Teams) icon from taskbar
Set-RegistryValue "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarMn" 0

# Remove Task View button from taskbar
Set-RegistryValue "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowTaskViewButton" 0

# Remove Widgets from taskbar
Set-RegistryValue "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarDa" 0
Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Dsh" "AllowNewsAndInterests" 0

# Center taskbar icons → left-aligned (optional, comment out to keep centered)
Set-RegistryValue "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarAl" 0

# ---------------------------------------------------------------------------
Write-Section "Privacy: Disable App Permissions"
# ---------------------------------------------------------------------------
# Microphone access (apps)
Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" "LetAppsAccessMicrophone" 2  # 2 = Force Deny
# Camera access (apps)
Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" "LetAppsAccessCamera" 2
# Location (apps)
Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" "LetAppsAccessLocation" 2
# Contacts (apps)
Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" "LetAppsAccessContacts" 2
# Notifications (apps)
Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy" "LetAppsAccessNotifications" 2

# ---------------------------------------------------------------------------
Write-Section "Disabling Windows Tips and Suggestions"
# ---------------------------------------------------------------------------
Set-RegistryValue "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SubscribedContent-310093Enabled" 0
Set-RegistryValue "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SubscribedContent-338387Enabled" 0
Set-RegistryValue "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Start_IrisRecommendations" 0
Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" "DisableSoftLanding" 1
Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" "DisableWindowsConsumerFeatures" 1
Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" "DisableCloudOptimizedContent" 1

# Disable "Get even more out of Windows" after setup
Set-RegistryValue "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE" "DisablePrivacyExperience" 1

# ---------------------------------------------------------------------------
Write-Section "Performance Tweaks"
# ---------------------------------------------------------------------------
# Disable visual effects for performance (set to "Adjust for best performance")
Set-RegistryValue "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" "VisualFXSetting" 2

# Disable transparency effects
Set-RegistryValue "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" "EnableTransparency" 0

# Show file extensions and hidden files in Explorer
Set-RegistryValue "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "HideFileExt" 0
Set-RegistryValue "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Hidden" 1

# Open Explorer to This PC instead of Quick Access
Set-RegistryValue "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "LaunchTo" 1

# Disable snap suggestions / snap layouts popup on hover
Set-RegistryValue "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "EnableSnapAssistFlyout" 0

# ---------------------------------------------------------------------------
Write-Section "Visual Cleanup - Making Windows Look Like Adults Use It"
# ---------------------------------------------------------------------------

# --- Dark mode (system + apps) ---
Set-RegistryValue "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" "AppsUseLightTheme" 0
Set-RegistryValue "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" "SystemUsesLightTheme" 0
Set-RegistryValue "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" "AppsUseLightTheme" 0
Set-RegistryValue "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" "SystemUsesLightTheme" 0

# --- Restore full right-click context menu (Win11 replaced it with a dumbed-down one) ---
# Sets InprocServer32 default to empty string, which re-enables the classic shell menu
$ctxKey = "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32"
if (-not (Test-Path $ctxKey)) { New-Item -Path $ctxKey -Force | Out-Null }
Set-ItemProperty -Path $ctxKey -Name "(Default)" -Value "" -Type String -Force
Write-Host "  Classic right-click context menu restored." -ForegroundColor Green

# --- Neutral accent color (dark slate grey instead of Windows blue) ---
# AccentColor is ABGR format: FF4C4C4C = opaque dark grey
Set-RegistryValue "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Accent" "AccentColor" 0xFF4C4C4C
Set-RegistryValue "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Accent" "AccentColorMenu" 0xFF4C4C4C
Set-RegistryValue "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Accent" "StartColorMenu" 0xFF2D2D2D

# Don't show accent color on taskbar/Start/title bars (keeps them plain dark)
Set-RegistryValue "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize" "ColorPrevalence" 0

# --- Remove color/glow from title bars - keep them dark and flat ---
Set-RegistryValue "HKCU:\SOFTWARE\Microsoft\Windows\DWM" "ColorPrevalence" 0
Set-RegistryValue "HKCU:\SOFTWARE\Microsoft\Windows\DWM" "EnableWindowColorization" 0

# --- Compact Explorer layout (tighter row height, like Windows 10) ---
Set-RegistryValue "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "UseCompactMode" 1

# --- Default Explorer view: Details, sorted by name, no group-by ---
# This writes the shell bag for all folders to use Details view
$shellKey = "HKCU:\SOFTWARE\Classes\Local Settings\Software\Microsoft\Windows\Shell\Bags\AllFolders\Shell"
Set-RegistryValue $shellKey "WFlags" 0x41200001
Set-RegistryValue $shellKey "Vid" "{137E7700-3573-11CF-AE69-08002B2E1262}"  # Details view GUID
Set-RegistryValue $shellKey "Mode" 4  # Details

# --- Disable "Shake to minimize all windows" (Aero Shake) ---
Set-RegistryValue "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "DisallowShaking" 1

# --- Disable sticky/filter/toggle keys popup (annoying accessibility prompts) ---
Set-RegistryValue "HKCU:\Control Panel\Accessibility\StickyKeys" "Flags" "506"
Set-RegistryValue "HKCU:\Control Panel\Accessibility\ToggleKeys" "Flags" "58"
Set-RegistryValue "HKCU:\Control Panel\Accessibility\Keyboard Response" "Flags" "122"

# --- Disable "AutoPlay" popups when inserting USB drives ---
Set-RegistryValue "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\AutoplayHandlers" "DisableAutoplay" 1
Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer" "NoAutoplayfornonVolume" 1

# --- Remove "- Shortcut" suffix when creating shortcuts ---
Set-RegistryValue "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" "link" ([byte[]](0,0,0,0)) "Binary"

# --- Taskbar: never combine buttons, show full labels ---
# 0 = never combine  1 = combine when full  2 = always combine
Set-RegistryValue "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarGlomLevel" 0
Set-RegistryValue "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "MMTaskbarGlomLevel" 0

# --- Clock: show seconds in taskbar clock ---
Set-RegistryValue "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowSecondsInSystemClock" 1

# --- Disable "News and interests" / Weather on hover ---
Set-RegistryValue "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Feeds" "ShellFeedsTaskbarViewMode" 2  # 2 = off

# --- Disable Copilot button on taskbar ---
Set-RegistryValue "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowCopilotButton" 0

# --- Lock screen: skip it on resume from sleep (desktop use) ---
Set-RegistryValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization" "NoLockScreen" 1

# ---------------------------------------------------------------------------
Write-Section "Restarting Explorer"
# ---------------------------------------------------------------------------
Write-Host "  Restarting Windows Explorer to apply taskbar/shell changes..." -ForegroundColor Yellow
Stop-Process -Name explorer -Force
Start-Sleep 2
Start-Process explorer

Write-Host ''
Write-Host '[DONE] Debloat complete.' -ForegroundColor Green
Write-Host 'A system restore point was created before any changes.' -ForegroundColor Green
Write-Host 'Some changes (services, registry) require a REBOOT to take full effect.' -ForegroundColor Cyan
Write-Host 'Recommended: reboot now.' -ForegroundColor Cyan
