#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Windows 11 Aggressive Debloat Script
.DESCRIPTION
    Removes bloatware, disables telemetry, strips unnecessary features.
    Creates a system restore point before changes. Uses dry-run + confirm approach.
.PARAMETER DryRunOnly
    Show what would change without applying anything.
.EXAMPLE
    .\debloat-win11.ps1
    .\debloat-win11.ps1 -DryRunOnly
#>
param(
    [switch]$DryRunOnly
)

$ErrorActionPreference = 'SilentlyContinue'
$LogFile = "$env:USERPROFILE\Desktop\Win11Debloat_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

# ── Helper Functions ──────────────────────────────────────────────────────────

function Write-Log {
    param(
        [string]$Message,
        [ConsoleColor]$Color = 'White'
    )
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    "$timestamp  $Message" | Out-File -Append -FilePath $LogFile -Encoding UTF8
    Write-Host $Message -ForegroundColor $Color
}

function Set-RegistryValue {
    param(
        [string]$Path,
        [string]$Name,
        $Value,
        [string]$Type = 'DWord'
    )
    if (-not (Test-Path $Path)) {
        New-Item -Path $Path -Force | Out-Null
    }
    Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force
}

function Test-RegistryValue {
    param(
        [string]$Path,
        [string]$Name,
        $Value
    )
    if (-not (Test-Path $Path)) { return $true }
    $current = Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue
    if ($null -eq $current) { return $true }
    return $current.$Name -ne $Value
}

# ── System Restore Point ─────────────────────────────────────────────────────

Write-Log '═══════════════════════════════════════════════════════' Cyan
Write-Log '  Windows 11 Debloat Script' Cyan
Write-Log '═══════════════════════════════════════════════════════' Cyan
Write-Log ''

Write-Log 'Creating system restore point...' Cyan
try {
    Enable-ComputerRestore -Drive 'C:\' -ErrorAction Stop
    Checkpoint-Computer -Description 'Pre-Win11Debloat' -RestorePointType 'MODIFY_SETTINGS' -ErrorAction Stop
    Write-Log '[OK] Restore point created.' Green
} catch {
    Write-Log "[WARN] Could not create restore point: $_" Yellow
    Write-Log '       (Windows limits restore points to one per 24 hours)' Yellow
}
Write-Log ''

# ── Define Actions ────────────────────────────────────────────────────────────

$actions = @()

# ─── Category 1: Bloatware Removal ───────────────────────────────────────────

$bloatwarePackages = @(
    'Microsoft.549981C3F5F10'               # Cortana
    'Microsoft.BingNews'                     # News
    'Microsoft.BingWeather'                  # Weather
    'Microsoft.Clipchamp'                    # Clipchamp
    'Clipchamp.Clipchamp'                    # Clipchamp (alt)
    'Microsoft.GamingApp'                    # Xbox Gaming (keep Xbox services, remove hub app)
    'Microsoft.GetHelp'                      # Get Help
    'Microsoft.Getstarted'                   # Tips
    'Microsoft.MicrosoftOfficeHub'           # Office Hub
    'Microsoft.MicrosoftSolitaireCollection' # Solitaire
    'Microsoft.MicrosoftStickyNotes'         # Sticky Notes
    'Microsoft.OutlookForWindows'            # New Outlook
    'Microsoft.People'                       # People
    'Microsoft.PowerAutomateDesktop'         # Power Automate
    'Microsoft.Todos'                        # To Do
    'Microsoft.WindowsAlarms'               # Alarms & Clock
    'microsoft.windowscommunicationsapps'    # Mail & Calendar
    'Microsoft.WindowsFeedbackHub'           # Feedback Hub
    'Microsoft.WindowsMaps'                  # Maps
    'Microsoft.WindowsSoundRecorder'         # Sound Recorder
    'Microsoft.YourPhone'                    # Phone Link
    'Microsoft.ZuneMusic'                    # Groove / Media Player
    'Microsoft.ZuneVideo'                    # Movies & TV
    'MicrosoftCorporationII.MicrosoftFamily' # Family
    'MicrosoftCorporationII.QuickAssist'     # Quick Assist
    'MicrosoftTeams'                         # Teams consumer
    'Microsoft.MicrosoftJournal'             # Journal
    'MSTeams'                                # Teams (alt ID)
    'Microsoft.BingSearch'                   # Bing Search
    'Microsoft.Copilot'                      # Windows Copilot
    'Microsoft.Edge.GameAssist'              # Edge Game Assist overlay
    'Microsoft.WidgetsPlatformRuntime'       # Widgets runtime
    'MicrosoftWindows.CrossDevice'           # Cross-device / Phone Link
    'RealtekSemiconductorCorp.RealtekAudioControl' # Realtek Store app (driver works without it)
)

# Wildcard third-party bloat
$bloatwareWildcards = @(
    '*CandyCrush*', '*BubbleWitch*', '*Disney*', '*Dolby*',
    '*Duolingo*', '*EclipseManager*', '*Facebook*', '*Flipboard*',
    '*Instagram*', '*Minecraft*', '*Netflix*', '*PandoraMedia*',
    '*Spotify*', '*TikTok*', '*Twitter*', '*Wunderlist*',
    '*LinkedInforWindows*', '*DevHome*',
    # ASUS bloatware
    '*ASUSPCAssistant*', '*ASUSProductRegistration*', '*ASUSGiftBox*',
    '*MyASUS*', '*ArmouryCrate*', '*ASUSSplendid*', '*GameVisual*',
    '*ASUSSystemDiagnosis*', '*ASUSScreensaver*', '*ASUSWallpaper*',
    '*ROGLiveService*', '*AuraCreator*', '*AuraSync*', '*AuraDeveloper*',
    '*ASUSSystemControl*', '*GlideX*', '*ScreenXpert*',
    # Windows AI / Recall workloads
    '*WindowsWorkload*'
)

# Keep list — these are excluded from wildcard matches
$keepPackages = @(
    'Microsoft.WindowsStore',
    'Microsoft.StorePurchaseApp',
    'Microsoft.WindowsCalculator',
    'Microsoft.WindowsNotepad',
    'Microsoft.Windows.Photos',
    'Microsoft.MSPaint',
    'Microsoft.WindowsCamera',
    'Microsoft.WindowsTerminal',
    'Microsoft.DesktopAppInstaller',
    'Microsoft.HEIFImageExtension',
    'Microsoft.VP9VideoExtensions',
    'Microsoft.WebMediaExtensions',
    'Microsoft.WebpImageExtension',
    'Microsoft.ScreenSketch',
    'Microsoft.OneDriveSync',
    'Microsoft.Xbox.TCUI',
    'Microsoft.XboxGameOverlay',
    'Microsoft.XboxGamingOverlay',
    'Microsoft.XboxIdentityProvider',
    'Microsoft.XboxSpeechToTextOverlay'
)

foreach ($pkg in $bloatwarePackages) {
    $pkgName = $pkg
    $actions += @{
        Category    = 'Bloatware'
        Description = "Remove $pkgName"
        Detect      = {
            $found = Get-AppxPackage -Name $pkgName -AllUsers -ErrorAction SilentlyContinue
            $provisioned = Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
                Where-Object { $_.DisplayName -eq $pkgName }
            return ($null -ne $found -or $null -ne $provisioned)
        }.GetNewClosure()
        Apply       = {
            Get-AppxPackage -Name $pkgName -AllUsers | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
            Get-AppxProvisionedPackage -Online |
                Where-Object { $_.DisplayName -eq $pkgName } |
                Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
        }.GetNewClosure()
    }
}

foreach ($pattern in $bloatwareWildcards) {
    $pat = $pattern
    $actions += @{
        Category    = 'Bloatware'
        Description = "Remove apps matching $pat"
        Detect      = {
            $found = Get-AppxPackage -Name $pat -AllUsers -ErrorAction SilentlyContinue |
                Where-Object { $keepPackages -notcontains $_.Name }
            return ($null -ne $found -and @($found).Count -gt 0)
        }.GetNewClosure()
        Apply       = {
            Get-AppxPackage -Name $pat -AllUsers |
                Where-Object { $keepPackages -notcontains $_.Name } |
                Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
        }.GetNewClosure()
    }
}

# ─── Category 1b: ASUS Bloatware (Win32 / non-Store) ────────────────────────

$asusUninstallNames = @(
    'ASUS Framework Service'
    'ASUS System Control Interface'
    'ASUS Splendid Video Enhancement Technology'
    'ASUS GiftBox'
    'MyASUS'
    'Armoury Crate'
    'Armoury Crate Lite Service'
    'Armoury Crate SE'
    'Armoury Crate Control Interface'
    'ASUS Optimization'
    'GameVisual'
    'ASUS System Diagnosis'
    'ROG Live Service'
    'Aura Creator'
    'Aura Sync'
    'AURA lighting effect add-on'
    'ASUS Product Registration'
    'GlideX'
    'ScreenXpert'
    'ASUS PC Cleaner'
    'ASUS USB Charger Plus'
    'ASUS Sonic Studio'
    'ASUS Sonic Radar'
    'ASUS AI Suite'
    'ASUS GPU Tweak'
    'ASUS Smart Gesture'
    'ASUS Screen Saver'
    'ASUS Wallpaper Component'
    'ICEsound'
    'ASUS Smart Connect'
    'ASUS Mini Bar'
    'ASUS Hello'
    # HAL / peripheral components
    'ASUS Aac_GmAcc HAL'
    'ASUS Aac_NBDT HAL'
    'ASUS Ambient HAL'
    'ASUS AURA Display Component'
    'ASUS AURA Headset Component'
    'ASUS Hotplug Controller'
    'ASUS Keyboard HAL'
    'ASUS MB Peripheral Products'
    'ASUS Monitor Control'
    'ASUS Mouse HAL'
    'ASUS Update Helper'
    'AniMeVisionFont'
)

$actions += @{
    Category    = 'ASUS Bloatware'
    Description = 'Uninstall ASUS Win32 programs'
    Detect      = {
        $uninstallPaths = @(
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
            'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
            'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
        )
        $installed = Get-ItemProperty $uninstallPaths -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -and ($asusUninstallNames | Where-Object { $installed.DisplayName -like "*$_*" }) }
        # Simpler: check if any ASUS entries exist
        $found = Get-ItemProperty $uninstallPaths -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -and $_.DisplayName -match 'ASUS|Armoury Crate|ROG Live|Aura Sync|Aura Creator|GameVisual|GlideX|ScreenXpert|ICEsound|AniMeVision' }
        return ($null -ne $found -and @($found).Count -gt 0)
    }
    Apply       = {
        $uninstallPaths = @(
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
            'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
            'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
        )
        $entries = Get-ItemProperty $uninstallPaths -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -and $_.DisplayName -match 'ASUS|Armoury Crate|ROG Live|Aura Sync|Aura Creator|GameVisual|GlideX|ScreenXpert|ICEsound|AniMeVision' }
        foreach ($entry in $entries) {
            $name = $entry.DisplayName
            $quiet = $entry.QuietUninstallString
            $uninstall = $entry.UninstallString
            $cmd = if ($quiet) { $quiet } elseif ($uninstall) { $uninstall } else { $null }
            if ($cmd) {
                Write-Log "    Uninstalling: $name" Cyan
                try {
                    if ($cmd -match 'msiexec') {
                        $cmd = $cmd -replace '/I', '/X'
                        if ($cmd -notmatch '/quiet') { $cmd += ' /quiet /norestart' }
                        cmd /c $cmd 2>&1 | Out-Null
                    } else {
                        cmd /c "`"$cmd`" /S /silent /quiet" 2>&1 | Out-Null
                    }
                } catch {
                    Write-Log "    [WARN] Could not uninstall $name : $_" Yellow
                }
            }
        }
    }
}

# ASUS services to disable
$asusServices = @(
    @{ Name='ASUSOptimization';         Desc='ASUS Optimization' }
    @{ Name='ASUSSystemAnalysis';       Desc='ASUS System Analysis' }
    @{ Name='ASUSSystemDiagnosis';      Desc='ASUS System Diagnosis' }
    @{ Name='AsusCertService';          Desc='ASUS Certificate Service' }
    @{ Name='ASUSLinkNear';             Desc='ASUS Link Near' }
    @{ Name='ASUSLinkRemote';           Desc='ASUS Link Remote' }
    @{ Name='ASUSSoftwareManager';      Desc='ASUS Software Manager' }
    @{ Name='ArmouryCrateControlInterface'; Desc='Armoury Crate Control Interface' }
    @{ Name='ArmouryCrateSEService';    Desc='Armoury Crate SE Service' }
    @{ Name='AsusAppService';           Desc='ASUS App Service' }
    @{ Name='ASUSROGLSLService';        Desc='ROG Live Service' }
    @{ Name='LightingService';          Desc='ASUS Aura Lighting Service' }
    @{ Name='GameSDK Service';          Desc='ASUS GameSDK Service' }
    @{ Name='AsSysCtrlService';         Desc='ASUS System Control Service' }
    @{ Name='ScreenXpertService';       Desc='ScreenXpert Service' }
)

foreach ($svc in $asusServices) {
    $s = $svc
    $actions += @{
        Category    = 'ASUS Services'
        Description = "Disable $($s.Desc) ($($s.Name))"
        Detect      = {
            $service = Get-Service -Name $s.Name -ErrorAction SilentlyContinue
            return ($null -ne $service -and $service.StartType -ne 'Disabled')
        }.GetNewClosure()
        Apply       = {
            Stop-Service -Name $s.Name -Force -ErrorAction SilentlyContinue
            Set-Service -Name $s.Name -StartupType Disabled -ErrorAction SilentlyContinue
        }.GetNewClosure()
    }
}

# ASUS scheduled tasks
$asusTaskPaths = @(
    '\ASUS\'
    '\ASUS\ArmouryCrate\'
    '\ASUS\MyASUS\'
    '\ASUS\ScreenXpert\'
    '\ASUS\GlideX\'
)

$actions += @{
    Category    = 'ASUS Tasks'
    Description = 'Disable all ASUS scheduled tasks'
    Detect      = {
        foreach ($tp in $asusTaskPaths) {
            $tasks = Get-ScheduledTask -TaskPath $tp -ErrorAction SilentlyContinue |
                Where-Object { $_.State -ne 'Disabled' }
            if ($tasks) { return $true }
        }
        # Also check root for ASUS-named tasks
        $rootTasks = Get-ScheduledTask -ErrorAction SilentlyContinue |
            Where-Object { $_.TaskName -match 'ASUS|Armoury|ArmouryCrate|MyASUS' -and $_.State -ne 'Disabled' }
        return ($null -ne $rootTasks -and @($rootTasks).Count -gt 0)
    }
    Apply       = {
        foreach ($tp in $asusTaskPaths) {
            Get-ScheduledTask -TaskPath $tp -ErrorAction SilentlyContinue |
                Disable-ScheduledTask -ErrorAction SilentlyContinue | Out-Null
        }
        Get-ScheduledTask -ErrorAction SilentlyContinue |
            Where-Object { $_.TaskName -match 'ASUS|Armoury|ArmouryCrate|MyASUS' } |
            Disable-ScheduledTask -ErrorAction SilentlyContinue | Out-Null
    }
}

# ASUS startup entries
$actions += @{
    Category    = 'ASUS Startup'
    Description = 'Disable ASUS startup entries'
    Detect      = {
        $runPaths = @(
            'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run',
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run',
            'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run'
        )
        foreach ($rp in $runPaths) {
            if (Test-Path $rp) {
                $props = Get-ItemProperty $rp -ErrorAction SilentlyContinue
                $names = $props.PSObject.Properties | Where-Object { $_.Name -match 'ASUS|Armoury|ROG|Aura|GameVisual|GlideX|ScreenXpert' }
                if ($names) { return $true }
            }
        }
        return $false
    }
    Apply       = {
        $runPaths = @(
            'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run',
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run',
            'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run'
        )
        foreach ($rp in $runPaths) {
            if (Test-Path $rp) {
                $props = Get-ItemProperty $rp -ErrorAction SilentlyContinue
                $names = $props.PSObject.Properties |
                    Where-Object { $_.Name -match 'ASUS|Armoury|ROG|Aura|GameVisual|GlideX|ScreenXpert' } |
                    Select-Object -ExpandProperty Name
                foreach ($name in $names) {
                    Remove-ItemProperty -Path $rp -Name $name -Force -ErrorAction SilentlyContinue
                    Write-Log "    Removed startup entry: $name from $rp" Cyan
                }
            }
        }
    }
}

# ─── Category 1c: NVIDIA Telemetry ──────────────────────────────────────────

$actions += @{
    Category    = 'NVIDIA Telemetry'
    Description = 'Uninstall NVIDIA Telemetry Client'
    Detect      = {
        $uninstallPaths = @(
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
            'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
        )
        $found = Get-ItemProperty $uninstallPaths -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -and $_.DisplayName -match 'NVIDIA Telemetry' }
        return ($null -ne $found -and @($found).Count -gt 0)
    }
    Apply       = {
        $uninstallPaths = @(
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
            'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
        )
        $entries = Get-ItemProperty $uninstallPaths -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -and $_.DisplayName -match 'NVIDIA Telemetry' }
        foreach ($entry in $entries) {
            $quiet = $entry.QuietUninstallString
            $uninstall = $entry.UninstallString
            $cmd = if ($quiet) { $quiet } elseif ($uninstall) { $uninstall } else { $null }
            if ($cmd) {
                Write-Log "    Uninstalling: $($entry.DisplayName)" Cyan
                try {
                    if ($cmd -match 'msiexec') {
                        $cmd = $cmd -replace '/I', '/X'
                        if ($cmd -notmatch '/quiet') { $cmd += ' /quiet /norestart' }
                        cmd /c $cmd 2>&1 | Out-Null
                    } else {
                        cmd /c "`"$cmd`" /S /silent /quiet" 2>&1 | Out-Null
                    }
                } catch {
                    Write-Log "    [WARN] Could not uninstall NVIDIA Telemetry: $_" Yellow
                }
            }
        }
    }
}

$nvidiaTelemetryServices = @(
    @{ Name='NvTelemetryContainer'; Desc='NVIDIA Telemetry Container' }
)

foreach ($svc in $nvidiaTelemetryServices) {
    $s = $svc
    $actions += @{
        Category    = 'NVIDIA Telemetry'
        Description = "Disable $($s.Desc) ($($s.Name))"
        Detect      = {
            $service = Get-Service -Name $s.Name -ErrorAction SilentlyContinue
            return ($null -ne $service -and $service.StartType -ne 'Disabled')
        }.GetNewClosure()
        Apply       = {
            Stop-Service -Name $s.Name -Force -ErrorAction SilentlyContinue
            Set-Service -Name $s.Name -StartupType Disabled -ErrorAction SilentlyContinue
        }.GetNewClosure()
    }
}

# NVIDIA telemetry scheduled tasks
$actions += @{
    Category    = 'NVIDIA Telemetry'
    Description = 'Disable NVIDIA telemetry scheduled tasks'
    Detect      = {
        $tasks = Get-ScheduledTask -ErrorAction SilentlyContinue |
            Where-Object { $_.TaskName -match 'NvTmMon|NvTmRep|NvProfile|NvNode' -and $_.State -ne 'Disabled' }
        return ($null -ne $tasks -and @($tasks).Count -gt 0)
    }
    Apply       = {
        Get-ScheduledTask -ErrorAction SilentlyContinue |
            Where-Object { $_.TaskName -match 'NvTmMon|NvTmRep|NvProfile|NvNode' } |
            Disable-ScheduledTask -ErrorAction SilentlyContinue | Out-Null
    }
}

# ─── Category 2: Telemetry & Privacy ─────────────────────────────────────────

$telemetrySettings = @(
    @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'; Name='AllowTelemetry'; Value=0; Desc='Disable telemetry data collection' }
    @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'; Name='AllowDeviceNameInTelemetry'; Value=0; Desc='Prevent device name in telemetry' }
    @{ Path='HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection'; Name='AllowTelemetry'; Value=0; Desc='Disable telemetry (secondary key)' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy'; Name='TailoredExperiencesWithDiagnosticDataEnabled'; Value=0; Desc='Disable tailored experiences' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo'; Name='Enabled'; Value=0; Desc='Disable advertising ID' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Input\TIPC'; Name='Enabled'; Value=0; Desc='Disable inking/typing data collection' }
    @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'; Name='PublishUserActivities'; Value=0; Desc='Disable activity history publishing' }
    @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'; Name='UploadUserActivities'; Value=0; Desc='Disable activity history upload' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name='Start_TrackProgs'; Value=0; Desc='Disable app launch tracking' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Siuf\Rules'; Name='NumberOfSIUFInPeriod'; Value=0; Desc='Disable feedback requests' }
    @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat'; Name='AITEnable'; Value=0; Desc='Disable Application Impact Telemetry' }
    @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\SQMClient\Windows'; Name='CEIPEnable'; Value=0; Desc='Disable CEIP' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name='SubscribedContent-338393Enabled'; Value=0; Desc='Disable suggested content in Settings' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name='SubscribedContent-353694Enabled'; Value=0; Desc='Disable suggested content in Settings (2)' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name='SubscribedContent-353696Enabled'; Value=0; Desc='Disable suggested content in Settings (3)' }
    @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors'; Name='DisableLocation'; Value=1; Desc='Disable location tracking' }
    @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Speech'; Name='AllowSpeechModelUpdate'; Value=0; Desc='Disable speech data collection' }
)

foreach ($setting in $telemetrySettings) {
    $s = $setting
    $actions += @{
        Category    = 'Telemetry'
        Description = $s.Desc
        Detect      = { Test-RegistryValue -Path $s.Path -Name $s.Name -Value $s.Value }.GetNewClosure()
        Apply       = { Set-RegistryValue -Path $s.Path -Name $s.Name -Value $s.Value }.GetNewClosure()
    }
}

# ─── Category 3: Cortana ─────────────────────────────────────────────────────

$cortanaSettings = @(
    @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search'; Name='AllowCortana'; Value=0; Desc='Disable Cortana' }
    @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search'; Name='AllowCortanaAboveLock'; Value=0; Desc='Disable Cortana on lock screen' }
    @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search'; Name='AllowSearchToUseLocation'; Value=0; Desc='Prevent search using location' }
    @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search'; Name='ConnectedSearchUseWeb'; Value=0; Desc='Disable web results in search' }
    @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search'; Name='DisableWebSearch'; Value=1; Desc='Disable web search' }
)

foreach ($setting in $cortanaSettings) {
    $s = $setting
    $actions += @{
        Category    = 'Cortana'
        Description = $s.Desc
        Detect      = { Test-RegistryValue -Path $s.Path -Name $s.Name -Value $s.Value }.GetNewClosure()
        Apply       = { Set-RegistryValue -Path $s.Path -Name $s.Name -Value $s.Value }.GetNewClosure()
    }
}

# ─── Category 5: Services ────────────────────────────────────────────────────

$servicesToDisable = @(
    @{ Name='DiagTrack';       Desc='Connected User Experiences and Telemetry' }
    @{ Name='dmwappushservice'; Desc='WAP Push Message Routing (telemetry)' }
    @{ Name='RetailDemo';      Desc='Retail Demo Service' }
    @{ Name='WMPNetworkSvc';   Desc='Windows Media Player Network Sharing' }
    @{ Name='MapsBroker';      Desc='Downloaded Maps Manager' }
    @{ Name='lfsvc';           Desc='Geolocation Service' }
    @{ Name='SharedAccess';    Desc='Internet Connection Sharing' }
    @{ Name='wisvc';           Desc='Windows Insider Service' }
)

foreach ($svc in $servicesToDisable) {
    $s = $svc
    $actions += @{
        Category    = 'Services'
        Description = "Disable $($s.Desc) ($($s.Name))"
        Detect      = {
            $service = Get-Service -Name $s.Name -ErrorAction SilentlyContinue
            return ($null -ne $service -and $service.StartType -ne 'Disabled')
        }.GetNewClosure()
        Apply       = {
            Stop-Service -Name $s.Name -Force -ErrorAction SilentlyContinue
            Set-Service -Name $s.Name -StartupType Disabled -ErrorAction SilentlyContinue
        }.GetNewClosure()
    }
}

# ─── Category 6: Scheduled Tasks ─────────────────────────────────────────────

$tasksToDisable = @(
    @{ Path='\Microsoft\Windows\Application Experience\'; Name='Microsoft Compatibility Appraiser' }
    @{ Path='\Microsoft\Windows\Application Experience\'; Name='ProgramDataUpdater' }
    @{ Path='\Microsoft\Windows\Customer Experience Improvement Program\'; Name='Consolidator' }
    @{ Path='\Microsoft\Windows\Customer Experience Improvement Program\'; Name='UsbCeip' }
    @{ Path='\Microsoft\Windows\Customer Experience Improvement Program\'; Name='KernelCeipTask' }
    @{ Path='\Microsoft\Windows\Autochk\'; Name='Proxy' }
    @{ Path='\Microsoft\Windows\DiskDiagnostic\'; Name='Microsoft-Windows-DiskDiagnosticDataCollector' }
    @{ Path='\Microsoft\Windows\Feedback\Siuf\'; Name='DmClient' }
    @{ Path='\Microsoft\Windows\Feedback\Siuf\'; Name='DmClientOnScenarioDownload' }
    @{ Path='\Microsoft\Windows\Windows Error Reporting\'; Name='QueueReporting' }
    @{ Path='\Microsoft\Windows\Maps\'; Name='MapsUpdateTask' }
    @{ Path='\Microsoft\Windows\Maps\'; Name='MapsToastTask' }
)

foreach ($task in $tasksToDisable) {
    $t = $task
    $actions += @{
        Category    = 'Scheduled Tasks'
        Description = "Disable task: $($t.Name)"
        Detect      = {
            $st = Get-ScheduledTask -TaskName $t.Name -TaskPath $t.Path -ErrorAction SilentlyContinue
            return ($null -ne $st -and $st.State -ne 'Disabled')
        }.GetNewClosure()
        Apply       = {
            Disable-ScheduledTask -TaskName $t.Name -TaskPath $t.Path -ErrorAction SilentlyContinue | Out-Null
        }.GetNewClosure()
    }
}

# ─── Category 7: UI Tweaks ───────────────────────────────────────────────────

$uiSettings = @(
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name='SystemPaneSuggestionsEnabled'; Value=0; Desc='Disable Start suggestions' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name='SilentInstalledAppsEnabled'; Value=0; Desc='Prevent silent app installs' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name='SoftLandingEnabled'; Value=0; Desc='Disable tip notifications' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name='RotatingLockScreenEnabled'; Value=0; Desc='Disable lock screen spotlight' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name='RotatingLockScreenOverlayEnabled'; Value=0; Desc='Disable lock screen overlay ads' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name='SubscribedContent-310093Enabled'; Value=0; Desc='Disable timeline suggestions' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name='SubscribedContent-338388Enabled'; Value=0; Desc='Disable Start suggestions (2)' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name='SubscribedContent-338389Enabled'; Value=0; Desc='Disable tips and tricks' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name='ContentDeliveryAllowed'; Value=0; Desc='Disable content delivery' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name='OemPreInstalledAppsEnabled'; Value=0; Desc='Disable OEM pre-installed apps' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name='PreInstalledAppsEnabled'; Value=0; Desc='Disable pre-installed apps' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name='PreInstalledAppsEverEnabled'; Value=0; Desc='Disable pre-installed apps (ever)' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name='HideFileExt'; Value=0; Desc='Show file extensions' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name='LaunchTo'; Value=1; Desc='Open Explorer to This PC' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search'; Name='BingSearchEnabled'; Value=0; Desc='Disable Bing web search in Start' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search'; Name='SearchboxTaskbarMode'; Value=1; Desc='Show search icon only (not full bar)' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings'; Name='NOC_GLOBAL_SETTING_ALLOW_TOASTS_ABOVE_LOCK'; Value=0; Desc='Disable notifications on lock screen' }
)

foreach ($setting in $uiSettings) {
    $s = $setting
    $actions += @{
        Category    = 'UI Tweaks'
        Description = $s.Desc
        Detect      = { Test-RegistryValue -Path $s.Path -Name $s.Name -Value $s.Value }.GetNewClosure()
        Apply       = { Set-RegistryValue -Path $s.Path -Name $s.Name -Value $s.Value }.GetNewClosure()
    }
}

# ─── Category 8: Windows Defender (Reduce Noise) ─────────────────────────────

$defenderSettings = @(
    @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'; Name='EnableSmartScreen'; Value=0; Desc='Disable SmartScreen UI prompts' }
    @{ Path='HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer'; Name='SmartScreenEnabled'; Value='Off'; Type='String'; Desc='Disable Explorer SmartScreen' }
    @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Reporting'; Name='DisableEnhancedNotifications'; Value=1; Desc='Reduce Defender notification noise' }
    @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender Security Center\Notifications'; Name='DisableNotifications'; Value=1; Desc='Disable Security Center notifications' }
    @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\MRT'; Name='DontOfferThroughWUAU'; Value=1; Desc='Disable Malicious Software Removal Tool via WU' }
)

foreach ($setting in $defenderSettings) {
    $s = $setting
    $type = if ($s.Type) { $s.Type } else { 'DWord' }
    $actions += @{
        Category    = 'Defender'
        Description = $s.Desc
        Detect      = { Test-RegistryValue -Path $s.Path -Name $s.Name -Value $s.Value }.GetNewClosure()
        Apply       = { Set-RegistryValue -Path $s.Path -Name $s.Name -Value $s.Value -Type $type }.GetNewClosure()
    }
}

# ─── Category 9: Edge ────────────────────────────────────────────────────────

$edgeSettings = @(
    @{ Name='HideFirstRunExperience'; Value=1; Desc='Skip Edge first-run wizard' }
    @{ Name='StandaloneHubsSidebarEnabled'; Value=0; Desc='Disable Edge standalone sidebar' }
    @{ Name='HubsSidebarEnabled'; Value=0; Desc='Disable Edge sidebar hubs' }
    @{ Name='EdgeShoppingAssistantEnabled'; Value=0; Desc='Disable Edge shopping assistant' }
    @{ Name='ShowMicrosoftRewards'; Value=0; Desc='Disable Edge rewards' }
    @{ Name='BrowserSignin'; Value=0; Desc='Disable Edge browser sign-in prompts' }
    @{ Name='UserFeedbackAllowed'; Value=0; Desc='Disable Edge feedback' }
    @{ Name='PersonalizationReportingEnabled'; Value=0; Desc='Disable Edge usage tracking' }
    @{ Name='DefaultBrowserSettingsCampaignEnabled'; Value=0; Desc='Disable default browser nag' }
    @{ Name='NewTabPageContentEnabled'; Value=0; Desc='Disable Edge new tab content' }
    @{ Name='NewTabPageHideDefaultTopSites'; Value=1; Desc='Hide Edge top sites on new tab' }
    @{ Name='NewTabPageBingChatEnabled'; Value=0; Desc='Disable Bing Chat on new tab' }
    @{ Name='CopilotPageContext'; Value=0; Desc='Disable Edge Copilot page context' }
    @{ Name='Microsoft365CopilotChatIconEnabled'; Value=0; Desc='Remove Edge Copilot icon' }
    @{ Name='EdgeCollectionsEnabled'; Value=0; Desc='Disable Edge Collections' }
    @{ Name='ShowRecommendationsEnabled'; Value=0; Desc='Disable Edge recommendations' }
    @{ Name='GuidedSwitchEnabled'; Value=0; Desc='Disable Edge browser switch prompts' }
    @{ Name='ForceSync'; Value=0; Desc='Prevent Edge forced sync' }
    @{ Name='ImplicitSignInEnabled'; Value=0; Desc='Prevent Edge auto sign-in' }
)

$edgePolicyPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'

foreach ($setting in $edgeSettings) {
    $s = $setting
    $actions += @{
        Category    = 'Edge'
        Description = $s.Desc
        Detect      = { Test-RegistryValue -Path $edgePolicyPath -Name $s.Name -Value $s.Value }.GetNewClosure()
        Apply       = { Set-RegistryValue -Path $edgePolicyPath -Name $s.Name -Value $s.Value }.GetNewClosure()
    }
}

# Edge desktop shortcut
$actions += @{
    Category    = 'Edge'
    Description = 'Prevent Edge desktop shortcut creation'
    Detect      = { Test-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\EdgeUpdate' -Name 'CreateDesktopShortcutDefault' -Value 0 }
    Apply       = { Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\EdgeUpdate' -Name 'CreateDesktopShortcutDefault' -Value 0 }
}

# ─── Category 10: Windows Update ─────────────────────────────────────────────

$wuSettings = @(
    @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'; Name='NoAutoRebootWithLoggedOnUsers'; Value=1; Desc='Prevent auto-restart while user logged in' }
    @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'; Name='AUOptions'; Value=4; Desc='Download and schedule install (not auto)' }
    @{ Path='HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config'; Name='DODownloadMode'; Value=0; Desc='Disable P2P delivery optimization' }
    @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization'; Name='DODownloadMode'; Value=0; Desc='Disable P2P delivery optimization (policy)' }
    @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'; Name='SetActiveHours'; Value=1; Desc='Enable active hours' }
    @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'; Name='ActiveHoursStart'; Value=8; Desc='Set active hours start: 8 AM' }
    @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'; Name='ActiveHoursEnd'; Value=23; Desc='Set active hours end: 11 PM' }
)

foreach ($setting in $wuSettings) {
    $s = $setting
    $actions += @{
        Category    = 'Windows Update'
        Description = $s.Desc
        Detect      = { Test-RegistryValue -Path $s.Path -Name $s.Name -Value $s.Value }.GetNewClosure()
        Apply       = { Set-RegistryValue -Path $s.Path -Name $s.Name -Value $s.Value }.GetNewClosure()
    }
}

# ─── Category 11: Classic Context Menu ────────────────────────────────────────

$actions += @{
    Category    = 'Context Menu'
    Description = 'Restore classic Windows 10 right-click context menu'
    Detect      = {
        $path = 'HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32'
        return -not (Test-Path $path)
    }
    Apply       = {
        $build = [System.Environment]::OSVersion.Version.Build
        if ($build -ge 26100) {
            Write-Log '  [WARN] Classic context menu registry method may not work on Windows 11 24H2+' Yellow
        }
        New-Item -Path 'HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32' -Value '' -Force | Out-Null
    }
}

# ─── Category 12: Widgets ────────────────────────────────────────────────────

$actions += @{
    Category    = 'Widgets'
    Description = 'Remove Widgets from taskbar'
    Detect      = { Test-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'TaskbarDa' -Value 0 }
    Apply       = { Set-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'TaskbarDa' -Value 0 }
}

$actions += @{
    Category    = 'Widgets'
    Description = 'Disable Widgets via policy'
    Detect      = { Test-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh' -Name 'AllowNewsAndInterests' -Value 0 }
    Apply       = { Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh' -Name 'AllowNewsAndInterests' -Value 0 }
}

$actions += @{
    Category    = 'Widgets'
    Description = 'Remove Widgets WebExperience package'
    Detect      = {
        $found = Get-AppxPackage -Name '*WebExperience*' -AllUsers -ErrorAction SilentlyContinue
        return ($null -ne $found)
    }
    Apply       = {
        Get-AppxPackage -Name '*WebExperience*' -AllUsers | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
        Get-AppxProvisionedPackage -Online |
            Where-Object { $_.DisplayName -like '*WebExperience*' } |
            Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
    }
}

# ─── Category 13: Teams Consumer / Chat Icon ─────────────────────────────────

$actions += @{
    Category    = 'Teams/Chat'
    Description = 'Remove Chat icon from taskbar'
    Detect      = { Test-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'TaskbarMn' -Value 0 }
    Apply       = { Set-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name 'TaskbarMn' -Value 0 }
}

$actions += @{
    Category    = 'Teams/Chat'
    Description = 'Hide Chat icon via policy'
    Detect      = { Test-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Chat' -Name 'ChatIcon' -Value 3 }
    Apply       = { Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Chat' -Name 'ChatIcon' -Value 3 }
}

# ─── Category 14: Windows Copilot & Recall ──────────────────────────────────

$copilotRecallSettings = @(
    @{ Path='HKCU:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot'; Name='TurnOffWindowsCopilot'; Value=1; Desc='Disable Windows Copilot (user)' }
    @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot'; Name='TurnOffWindowsCopilot'; Value=1; Desc='Disable Windows Copilot (machine)' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name='ShowCopilotButton'; Value=0; Desc='Hide Copilot button from taskbar' }
    @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI'; Name='DisableAIDataAnalysis'; Value=1; Desc='Disable Windows Recall' }
    @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI'; Name='TurnOffSavingSnapshots'; Value=1; Desc='Disable Recall snapshots' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name='RecallEnabled'; Value=0; Desc='Disable Recall (user setting)' }
)

foreach ($setting in $copilotRecallSettings) {
    $s = $setting
    $actions += @{
        Category    = 'Copilot/Recall'
        Description = $s.Desc
        Detect      = { Test-RegistryValue -Path $s.Path -Name $s.Name -Value $s.Value }.GetNewClosure()
        Apply       = { Set-RegistryValue -Path $s.Path -Name $s.Name -Value $s.Value }.GetNewClosure()
    }
}

# ─── Category 15: Game Bar / Game DVR ────────────────────────────────────────

$gameBarSettings = @(
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR'; Name='AppCaptureEnabled'; Value=0; Desc='Disable Game DVR capture' }
    @{ Path='HKCU:\System\GameConfigStore'; Name='GameDVR_Enabled'; Value=0; Desc='Disable Game DVR' }
    @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR'; Name='AllowGameDVR'; Value=0; Desc='Disable Game DVR (policy)' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\GameBar'; Name='UseNexusForGameBarEnabled'; Value=0; Desc='Disable Game Bar overlay' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\GameBar'; Name='AutoGameModeEnabled'; Value=0; Desc='Disable auto Game Mode' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\GameBar'; Name='ShowStartupPanel'; Value=0; Desc='Disable Game Bar startup panel' }
)

foreach ($setting in $gameBarSettings) {
    $s = $setting
    $actions += @{
        Category    = 'Game Bar'
        Description = $s.Desc
        Detect      = { Test-RegistryValue -Path $s.Path -Name $s.Name -Value $s.Value }.GetNewClosure()
        Apply       = { Set-RegistryValue -Path $s.Path -Name $s.Name -Value $s.Value }.GetNewClosure()
    }
}

# ─── Category 16: Taskbar Cleanup ────────────────────────────────────────────

$taskbarSettings = @(
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name='ShowTaskViewButton'; Value=0; Desc='Hide Task View button' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name='TaskbarAl'; Value=0; Desc='Align taskbar to left' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\SearchSettings'; Name='IsDynamicSearchBoxEnabled'; Value=0; Desc='Disable search highlights' }
)

foreach ($setting in $taskbarSettings) {
    $s = $setting
    $actions += @{
        Category    = 'Taskbar'
        Description = $s.Desc
        Detect      = { Test-RegistryValue -Path $s.Path -Name $s.Name -Value $s.Value }.GetNewClosure()
        Apply       = { Set-RegistryValue -Path $s.Path -Name $s.Name -Value $s.Value }.GetNewClosure()
    }
}

# ─── Category 17: Start Menu Recommendations ────────────────────────────────

$startMenuSettings = @(
    @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer'; Name='HideRecommendedSection'; Value=1; Desc='Hide Recommended section in Start' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name='Start_IrisRecommendations'; Value=0; Desc='Disable Start menu account recommendations' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name='Start_AccountNotifications'; Value=0; Desc='Disable Start menu account notifications' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name='SubscribedContent-338388Enabled'; Value=0; Desc='Disable Start menu suggestions' }
)

foreach ($setting in $startMenuSettings) {
    $s = $setting
    $actions += @{
        Category    = 'Start Menu'
        Description = $s.Desc
        Detect      = { Test-RegistryValue -Path $s.Path -Name $s.Name -Value $s.Value }.GetNewClosure()
        Apply       = { Set-RegistryValue -Path $s.Path -Name $s.Name -Value $s.Value }.GetNewClosure()
    }
}

# ─── Category 18: Background Apps ───────────────────────────────────────────

$actions += @{
    Category    = 'Background Apps'
    Description = 'Disable UWP background apps globally'
    Detect      = { Test-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications' -Name 'GlobalUserDisabled' -Value 1 }
    Apply       = { Set-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications' -Name 'GlobalUserDisabled' -Value 1 }
}

$actions += @{
    Category    = 'Background Apps'
    Description = 'Disable background apps (policy)'
    Detect      = { Test-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy' -Name 'LetAppsRunInBackground' -Value 2 }
    Apply       = { Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy' -Name 'LetAppsRunInBackground' -Value 2 }
}

# ─── Category 19: Clipboard Cloud Sync ──────────────────────────────────────

$clipboardSettings = @(
    @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'; Name='AllowClipboardHistory'; Value=0; Desc='Disable clipboard history' }
    @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'; Name='AllowCrossDeviceClipboard'; Value=0; Desc='Disable cross-device clipboard sync' }
)

foreach ($setting in $clipboardSettings) {
    $s = $setting
    $actions += @{
        Category    = 'Clipboard'
        Description = $s.Desc
        Detect      = { Test-RegistryValue -Path $s.Path -Name $s.Name -Value $s.Value }.GetNewClosure()
        Apply       = { Set-RegistryValue -Path $s.Path -Name $s.Name -Value $s.Value }.GetNewClosure()
    }
}

# ─── Category 20: Additional Services ───────────────────────────────────────

$extraServices = @(
    @{ Name='SysMain';        Desc='SysMain / Superfetch (unnecessary on SSDs)' }
    @{ Name='Fax';            Desc='Fax Service' }
    @{ Name='WSearch';        Desc='Windows Search Indexer (uses disk/CPU in background)' }
    @{ Name='WerSvc';         Desc='Windows Error Reporting' }
    @{ Name='DPS';            Desc='Diagnostic Policy Service' }
    @{ Name='WdiServiceHost'; Desc='Diagnostic Service Host' }
    @{ Name='WdiSystemHost';  Desc='Diagnostic System Host' }
    @{ Name='CDPSvc';         Desc='Connected Devices Platform Service' }
    @{ Name='CDPUserSvc';     Desc='Connected Devices Platform User Service' }
    @{ Name='PcaSvc';         Desc='Program Compatibility Assistant' }
    @{ Name='PhoneSvc';       Desc='Phone Service (landline telephony)' }
)

foreach ($svc in $extraServices) {
    $s = $svc
    $actions += @{
        Category    = 'Services'
        Description = "Disable $($s.Desc) ($($s.Name))"
        Detect      = {
            $service = Get-Service -Name $s.Name -ErrorAction SilentlyContinue
            return ($null -ne $service -and $service.StartType -ne 'Disabled')
        }.GetNewClosure()
        Apply       = {
            Stop-Service -Name $s.Name -Force -ErrorAction SilentlyContinue
            Set-Service -Name $s.Name -StartupType Disabled -ErrorAction SilentlyContinue
        }.GetNewClosure()
    }
}

# ─── Category 21: OneDrive Nags ─────────────────────────────────────────────

$oneDriveNagSettings = @(
    @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive'; Name='DisableFileSyncNGSC'; Value=0; Desc='Keep OneDrive sync but suppress setup nag' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name='ShowSyncProviderNotifications'; Value=0; Desc='Disable OneDrive ads in File Explorer' }
    @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\OneDrive'; Name='KFMBlockOptIn'; Value=1; Desc='Block OneDrive Known Folder Move prompts' }
)

foreach ($setting in $oneDriveNagSettings) {
    $s = $setting
    $actions += @{
        Category    = 'OneDrive Nags'
        Description = $s.Desc
        Detect      = { Test-RegistryValue -Path $s.Path -Name $s.Name -Value $s.Value }.GetNewClosure()
        Apply       = { Set-RegistryValue -Path $s.Path -Name $s.Name -Value $s.Value }.GetNewClosure()
    }
}

# ─── Category 22: Post-Update Nag Screens ───────────────────────────────────

$nagSettings = @(
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name='SubscribedContent-310093Enabled'; Value=0; Desc='Disable "Welcome Experience" after updates' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name='SubscribedContent-338387Enabled'; Value=0; Desc='Disable "Get even more out of Windows" nag' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\UserProfileEngagement'; Name='ScoobeSystemSettingEnabled'; Value=0; Desc='Disable "Finish setting up" nag' }
    @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\OOBE'; Name='DisablePrivacyExperience'; Value=1; Desc='Disable post-update privacy settings screen' }
)

foreach ($setting in $nagSettings) {
    $s = $setting
    $actions += @{
        Category    = 'Nag Screens'
        Description = $s.Desc
        Detect      = { Test-RegistryValue -Path $s.Path -Name $s.Name -Value $s.Value }.GetNewClosure()
        Apply       = { Set-RegistryValue -Path $s.Path -Name $s.Name -Value $s.Value }.GetNewClosure()
    }
}

# ─── Category 23: Find My Device ────────────────────────────────────────────

$actions += @{
    Category    = 'Privacy'
    Description = 'Disable Find My Device'
    Detect      = { Test-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\FindMyDevice' -Name 'AllowFindMyDevice' -Value 0 }
    Apply       = { Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\FindMyDevice' -Name 'AllowFindMyDevice' -Value 0 }
}

# ─── Category 25: Typing Insights / Inking ──────────────────────────────────

$typingSettings = @(
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name='Start_TrackDocs'; Value=0; Desc='Disable recent documents tracking' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Personalization\Settings'; Name='AcceptedPrivacyPolicy'; Value=0; Desc='Disable typing personalization' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CPSS\Store\InkingAndTypingPersonalization'; Name='Value'; Value=0; Desc='Disable inking and typing personalization' }
    @{ Path='HKLM:\SOFTWARE\Microsoft\PolicyManager\default\TextInput\AllowLinguisticDataCollection'; Name='value'; Value=0; Desc='Disable linguistic data collection' }
)

foreach ($setting in $typingSettings) {
    $s = $setting
    $actions += @{
        Category    = 'Privacy'
        Description = $s.Desc
        Detect      = { Test-RegistryValue -Path $s.Path -Name $s.Name -Value $s.Value }.GetNewClosure()
        Apply       = { Set-RegistryValue -Path $s.Path -Name $s.Name -Value $s.Value }.GetNewClosure()
    }
}

# ─── Category 26: Telemetry Env Vars (PowerShell / .NET CLI) ────────────────

$actions += @{
    Category    = 'Telemetry'
    Description = 'Opt out of PowerShell telemetry'
    Detect      = {
        $val = [System.Environment]::GetEnvironmentVariable('POWERSHELL_TELEMETRY_OPTOUT', 'Machine')
        return ($val -ne '1')
    }
    Apply       = {
        [System.Environment]::SetEnvironmentVariable('POWERSHELL_TELEMETRY_OPTOUT', '1', 'Machine')
    }
}

$actions += @{
    Category    = 'Telemetry'
    Description = 'Opt out of .NET CLI telemetry'
    Detect      = {
        $val = [System.Environment]::GetEnvironmentVariable('DOTNET_CLI_TELEMETRY_OPTOUT', 'Machine')
        return ($val -ne '1')
    }
    Apply       = {
        [System.Environment]::SetEnvironmentVariable('DOTNET_CLI_TELEMETRY_OPTOUT', '1', 'Machine')
    }
}

# ─── Category 27: Sticky Keys / Filter Keys Prompts ─────────────────────────

$accessibilitySettings = @(
    @{ Path='HKCU:\Control Panel\Accessibility\StickyKeys'; Name='Flags'; Value='506'; Type='String'; Desc='Disable Sticky Keys shortcut prompt (5x Shift)' }
    @{ Path='HKCU:\Control Panel\Accessibility\Keyboard Response'; Name='Flags'; Value='122'; Type='String'; Desc='Disable Filter Keys shortcut prompt (hold Shift)' }
    @{ Path='HKCU:\Control Panel\Accessibility\ToggleKeys'; Name='Flags'; Value='58'; Type='String'; Desc='Disable Toggle Keys shortcut prompt' }
)

foreach ($setting in $accessibilitySettings) {
    $s = $setting
    $type = if ($s.Type) { $s.Type } else { 'DWord' }
    $actions += @{
        Category    = 'Accessibility'
        Description = $s.Desc
        Detect      = { Test-RegistryValue -Path $s.Path -Name $s.Name -Value $s.Value }.GetNewClosure()
        Apply       = { Set-RegistryValue -Path $s.Path -Name $s.Name -Value $s.Value -Type $type }.GetNewClosure()
    }
}

# ─── Category 28: Autoplay ──────────────────────────────────────────────────

$actions += @{
    Category    = 'Autoplay'
    Description = 'Disable Autoplay for all media and devices'
    Detect      = { Test-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\AutoplayHandlers' -Name 'DisableAutoplay' -Value 1 }
    Apply       = { Set-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\AutoplayHandlers' -Name 'DisableAutoplay' -Value 1 }
}

$actions += @{
    Category    = 'Autoplay'
    Description = 'Disable Autoplay via policy'
    Detect      = { Test-RegistryValue -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' -Name 'NoDriveTypeAutoRun' -Value 255 }
    Apply       = { Set-RegistryValue -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' -Name 'NoDriveTypeAutoRun' -Value 255 }
}

# ─── Category 29: Edge Scheduled Tasks ──────────────────────────────────────

$actions += @{
    Category    = 'Edge'
    Description = 'Disable Edge auto-update scheduled tasks'
    Detect      = {
        $tasks = Get-ScheduledTask -ErrorAction SilentlyContinue |
            Where-Object { $_.TaskName -match 'MicrosoftEdgeUpdate' -and $_.State -ne 'Disabled' }
        return ($null -ne $tasks -and @($tasks).Count -gt 0)
    }
    Apply       = {
        Get-ScheduledTask -ErrorAction SilentlyContinue |
            Where-Object { $_.TaskName -match 'MicrosoftEdgeUpdate' } |
            Disable-ScheduledTask -ErrorAction SilentlyContinue | Out-Null
    }
}

# ─── Category 30: Windows Ink Workspace ─────────────────────────────────────

$actions += @{
    Category    = 'Ink Workspace'
    Description = 'Disable Windows Ink Workspace'
    Detect      = { Test-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\WindowsInkWorkspace' -Name 'AllowWindowsInkWorkspace' -Value 0 }
    Apply       = { Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\WindowsInkWorkspace' -Name 'AllowWindowsInkWorkspace' -Value 0 }
}

$actions += @{
    Category    = 'Ink Workspace'
    Description = 'Disable Ink Workspace suggested apps'
    Detect      = { Test-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\WindowsInkWorkspace' -Name 'AllowSuggestedAppsInWindowsInkWorkspace' -Value 0 }
    Apply       = { Set-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\WindowsInkWorkspace' -Name 'AllowSuggestedAppsInWindowsInkWorkspace' -Value 0 }
}

# ─── Category 31: Clean Start Menu Layout ───────────────────────────────────

$actions += @{
    Category    = 'Start Menu'
    Description = 'Reset Start menu pinned tiles to clean layout'
    Detect      = {
        $layoutFile = "$env:LOCALAPPDATA\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState\start2.bin"
        if (-not (Test-Path $layoutFile)) { return $false }
        # Check if file is larger than a minimal layout (indicates bloat tiles present)
        $size = (Get-Item $layoutFile -ErrorAction SilentlyContinue).Length
        return ($size -gt 10240)  # >10KB suggests pre-pinned bloat
    }
    Apply       = {
        $layoutFile = "$env:LOCALAPPDATA\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState\start2.bin"
        if (Test-Path $layoutFile) {
            # Back up current layout
            Copy-Item $layoutFile "$layoutFile.bak" -Force -ErrorAction SilentlyContinue
            Remove-Item $layoutFile -Force -ErrorAction SilentlyContinue
            Write-Log '    Start menu layout reset (backup saved as start2.bin.bak). Pins will rebuild on next login.' Cyan
        }
    }
}

# ─── Category 32: Printer Bloatware ─────────────────────────────────────────

$printerBloatWildcards = @(
    '*HPSmart*', '*HPPrinter*', '*HPDesktop*', '*HPConnected*', '*HPEasyStart*',
    '*HPJumpStart*', '*HPWorkWell*', '*HPPCHardwareDiagnostics*',
    '*CanonInkjet*', '*CanonPrinter*', '*CanonUtilities*',
    '*EpsonPrinter*', '*EpsonScan*', '*EpsonUtilities*',
    '*BrotherPrinter*', '*BrotherUtilities*',
    '*LexmarkPrinter*', '*SamsungPrinter*'
)

foreach ($pattern in $printerBloatWildcards) {
    $pat = $pattern
    $actions += @{
        Category    = 'Printer Bloat'
        Description = "Remove apps matching $pat"
        Detect      = {
            $found = Get-AppxPackage -Name $pat -AllUsers -ErrorAction SilentlyContinue
            return ($null -ne $found -and @($found).Count -gt 0)
        }.GetNewClosure()
        Apply       = {
            Get-AppxPackage -Name $pat -AllUsers |
                Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
            Get-AppxProvisionedPackage -Online |
                Where-Object { $_.DisplayName -like $pat } |
                Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
        }.GetNewClosure()
    }
}

# Also remove Win32 printer bloat (HP Smart etc.)
$actions += @{
    Category    = 'Printer Bloat'
    Description = 'Uninstall HP/Canon/Epson Win32 bloatware'
    Detect      = {
        $uninstallPaths = @(
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
            'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
        )
        $found = Get-ItemProperty $uninstallPaths -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -and $_.DisplayName -match 'HP Smart|HP Easy Start|HP JumpStart|HP PC Hardware|HP WorkWell|Canon Inkjet|Epson Software|Epson Scan' }
        return ($null -ne $found -and @($found).Count -gt 0)
    }
    Apply       = {
        $uninstallPaths = @(
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
            'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
        )
        $entries = Get-ItemProperty $uninstallPaths -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -and $_.DisplayName -match 'HP Smart|HP Easy Start|HP JumpStart|HP PC Hardware|HP WorkWell|Canon Inkjet|Epson Software|Epson Scan' }
        foreach ($entry in $entries) {
            $name = $entry.DisplayName
            $quiet = $entry.QuietUninstallString
            $uninstall = $entry.UninstallString
            $cmd = if ($quiet) { $quiet } elseif ($uninstall) { $uninstall } else { $null }
            if ($cmd) {
                Write-Log "    Uninstalling: $name" Cyan
                try {
                    if ($cmd -match 'msiexec') {
                        $cmd = $cmd -replace '/I', '/X'
                        if ($cmd -notmatch '/quiet') { $cmd += ' /quiet /norestart' }
                        cmd /c $cmd 2>&1 | Out-Null
                    } else {
                        cmd /c "`"$cmd`" /S /silent /quiet" 2>&1 | Out-Null
                    }
                } catch {
                    Write-Log "    [WARN] Could not uninstall $name : $_" Yellow
                }
            }
        }
    }
}

# ─── Category 33: Visual Effects / Performance ──────────────────────────────

$visualSettings = @(
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize'; Name='EnableTransparency'; Value=0; Desc='Disable transparency effects' }
    @{ Path='HKCU:\Control Panel\Desktop'; Name='UserPreferencesMask'; Value=([byte[]](0x90,0x12,0x03,0x80,0x10,0x00,0x00,0x00)); Type='Binary'; Desc='Disable most visual animations' }
    @{ Path='HKCU:\Control Panel\Desktop'; Name='MenuShowDelay'; Value='0'; Type='String'; Desc='Remove menu show delay' }
    @{ Path='HKCU:\Control Panel\Desktop\WindowMetrics'; Name='MinAnimate'; Value='0'; Type='String'; Desc='Disable minimize/maximize animations' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name='TaskbarAnimations'; Value=0; Desc='Disable taskbar animations' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\DWM'; Name='EnableAeroPeek'; Value=0; Desc='Disable Aero Peek' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\DWM'; Name='AlwaysHibernateThumbnails'; Value=0; Desc='Disable taskbar thumbnail previews' }
    @{ Path='HKCU:\Control Panel\Desktop'; Name='DragFullWindows'; Value='0'; Type='String'; Desc='Disable show window contents while dragging' }
)

foreach ($setting in $visualSettings) {
    $s = $setting
    $type = if ($s.Type) { $s.Type } else { 'DWord' }
    $actions += @{
        Category    = 'Performance'
        Description = $s.Desc
        Detect      = {
            if ($type -eq 'Binary') {
                # Binary comparison
                if (-not (Test-Path $s.Path)) { return $true }
                $current = (Get-ItemProperty -Path $s.Path -Name $s.Name -ErrorAction SilentlyContinue).$($s.Name)
                if ($null -eq $current) { return $true }
                return ([System.BitConverter]::ToString($current) -ne [System.BitConverter]::ToString($s.Value))
            }
            Test-RegistryValue -Path $s.Path -Name $s.Name -Value $s.Value
        }.GetNewClosure()
        Apply       = { Set-RegistryValue -Path $s.Path -Name $s.Name -Value $s.Value -Type $type }.GetNewClosure()
    }
}

# Disable visual effects via SystemPropertiesPerformance equivalent
$actions += @{
    Category    = 'Performance'
    Description = 'Set Visual Effects to "Adjust for best performance"'
    Detect      = { Test-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects' -Name 'VisualFXSetting' -Value 2 }
    Apply       = { Set-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects' -Name 'VisualFXSetting' -Value 2 }
}

# ─── Category 34: Recent Files / Quick Access ───────────────────────────────

$recentSettings = @(
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer'; Name='ShowRecent'; Value=0; Desc='Disable recent files in Quick Access' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer'; Name='ShowFrequent'; Value=0; Desc='Disable frequent folders in Quick Access' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name='Start_TrackDocs'; Value=0; Desc='Disable recent documents in Start/taskbar' }
)

foreach ($setting in $recentSettings) {
    $s = $setting
    $actions += @{
        Category    = 'Explorer'
        Description = $s.Desc
        Detect      = { Test-RegistryValue -Path $s.Path -Name $s.Name -Value $s.Value }.GetNewClosure()
        Apply       = { Set-RegistryValue -Path $s.Path -Name $s.Name -Value $s.Value }.GetNewClosure()
    }
}

# Clear existing recent files and jump lists
$actions += @{
    Category    = 'Explorer'
    Description = 'Clear recent files and jump list history'
    Detect      = {
        $recentPath = "$env:APPDATA\Microsoft\Windows\Recent"
        $items = Get-ChildItem $recentPath -ErrorAction SilentlyContinue
        return ($null -ne $items -and @($items).Count -gt 5)
    }
    Apply       = {
        $recentPath = "$env:APPDATA\Microsoft\Windows\Recent"
        Remove-Item "$recentPath\*" -Recurse -Force -ErrorAction SilentlyContinue
        $autoPath = "$recentPath\AutomaticDestinations"
        Remove-Item "$autoPath\*" -Force -ErrorAction SilentlyContinue
        $customPath = "$recentPath\CustomDestinations"
        Remove-Item "$customPath\*" -Force -ErrorAction SilentlyContinue
        Write-Log '    Cleared recent files and jump list history.' Cyan
    }
}

# ── Dry Run Phase ─────────────────────────────────────────────────────────────

Write-Log '── Scanning system ─────────────────────────────────────' Cyan
Write-Log ''

$pending = @()
$alreadyOk = 0

foreach ($action in $actions) {
    try {
        $needed = & $action.Detect
    } catch {
        $needed = $false
    }

    if ($needed) {
        $pending += $action
        Write-Host "  [PENDING]  " -ForegroundColor Yellow -NoNewline
        Write-Host "$($action.Category): $($action.Description)"
    } else {
        $alreadyOk++
    }
}

Write-Log ''
Write-Log '── Summary ─────────────────────────────────────────────' Cyan
Write-Log "  Changes needed:    $($pending.Count)" Yellow
Write-Log "  Already applied:   $alreadyOk" Green
Write-Log "  Total checked:     $($actions.Count)" Cyan
Write-Log ''

if ($pending.Count -eq 0) {
    Write-Log 'Nothing to do — system is already debloated!' Green
    exit 0
}

if ($DryRunOnly) {
    Write-Log 'Dry-run complete. Run without -DryRunOnly to apply changes.' Cyan
    exit 0
}

# ── Confirmation ──────────────────────────────────────────────────────────────

Write-Host ''
$confirm = Read-Host "Apply $($pending.Count) changes? (y/N)"
if ($confirm -ne 'y' -and $confirm -ne 'Y') {
    Write-Log 'Cancelled by user.' Yellow
    exit 0
}

# ── Apply Phase ───────────────────────────────────────────────────────────────

Write-Log ''
Write-Log '── Applying changes ────────────────────────────────────' Cyan
Write-Log ''

$success = 0
$failed = 0

foreach ($action in $pending) {
    try {
        & $action.Apply
        Write-Log "  [APPLIED]  $($action.Category): $($action.Description)" Green
        $success++
    } catch {
        Write-Log "  [FAILED]   $($action.Category): $($action.Description) - $_" Red
        $failed++
    }
}

# ── Final Summary ─────────────────────────────────────────────────────────────

Write-Log ''
Write-Log '═══════════════════════════════════════════════════════' Cyan
Write-Log '  Debloat Complete!' Cyan
Write-Log '═══════════════════════════════════════════════════════' Cyan
Write-Log "  Applied:   $success" Green
if ($failed -gt 0) {
    Write-Log "  Failed:    $failed" Red
}
Write-Log "  Log file:  $LogFile" Cyan
Write-Log ''
Write-Log 'A restart is recommended for all changes to take effect.' Yellow

$restart = Read-Host 'Restart now? (y/N)'
if ($restart -eq 'y' -or $restart -eq 'Y') {
    Restart-Computer -Force
}
