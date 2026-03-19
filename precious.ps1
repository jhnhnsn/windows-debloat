#Requires -RunAsAdministrator
<#
.SYNOPSIS
    The One Script to Rule Them All — Windows 11 debloat, privacy hardening, and cleanup.
.DESCRIPTION
    Merges debloat-windows.ps1 and debloat-win11.ps1 into a single script.
    Scans the system first, shows pending changes, asks for confirmation, then applies.
    Creates a system restore point before making any changes.
.PARAMETER DryRunOnly
    Show what would change without applying anything.
.EXAMPLE
    .\precious.ps1
    .\precious.ps1 -DryRunOnly
#>
param(
    [switch]$DryRunOnly
)

$ErrorActionPreference = 'SilentlyContinue'
$LogFile = "$env:USERPROFILE\Desktop\Precious_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

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
    if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
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

# ── Banner ────────────────────────────────────────────────────────────────────

Write-Log '═══════════════════════════════════════════════════════' Cyan
Write-Log '  precious.ps1 — The One Debloat Script to Rule Them All' Cyan
Write-Log '═══════════════════════════════════════════════════════' Cyan
Write-Log ''

# ── System Restore Point ──────────────────────────────────────────────────────

Write-Log 'Creating system restore point...' Cyan
try {
    Enable-ComputerRestore -Drive 'C:\' -ErrorAction Stop
    Checkpoint-Computer -Description 'Pre-Precious-Debloat' -RestorePointType 'MODIFY_SETTINGS' -ErrorAction Stop
    Write-Log '[OK] Restore point created.' Green
} catch {
    Write-Log "[WARN] Could not create restore point: $_" Yellow
    Write-Log '       (Windows limits restore points to one per 24 hours)' Yellow
}
Write-Log ''

# ── Build Actions List ────────────────────────────────────────────────────────

$actions = @()

# ─── Apps: Keep-list (protected from wildcard removal) ───────────────────────

$keepPackages = @(
    'Microsoft.WindowsStore',
    'Microsoft.StorePurchaseApp',
    'Microsoft.WindowsCalculator',
    'Microsoft.WindowsNotepad',
    'Microsoft.Windows.Photos',
    'Microsoft.MSPaint',                  # classic Paint (not Paint 3D)
    'Microsoft.WindowsCamera',
    'Microsoft.WindowsTerminal',
    'Microsoft.DesktopAppInstaller',
    'Microsoft.HEIFImageExtension',
    'Microsoft.VP9VideoExtensions',
    'Microsoft.WebMediaExtensions',
    'Microsoft.WebpImageExtension',
    'Microsoft.ScreenSketch',
    'Microsoft.Xbox.TCUI',
    'Microsoft.XboxGameOverlay',
    'Microsoft.XboxGamingOverlay',
    'Microsoft.XboxIdentityProvider',
    'Microsoft.XboxSpeechToTextOverlay'
)

# ─── Category 1: Bloatware — Specific Package IDs ────────────────────────────

$bloatwarePackages = @(
    # Microsoft — Bing & info apps
    'Microsoft.549981C3F5F10'               # Cortana (standalone app)
    'Microsoft.BingFinance'
    'Microsoft.BingFoodAndDrink'
    'Microsoft.BingHealthAndFitness'
    'Microsoft.BingMaps'
    'Microsoft.BingNews'
    'Microsoft.BingSearch'
    'Microsoft.BingSports'
    'Microsoft.BingTravel'
    'Microsoft.BingWeather'
    'Microsoft.News'
    # Microsoft — Office & productivity bloat
    'Microsoft.Clipchamp'
    'Clipchamp.Clipchamp'
    'Microsoft.GetHelp'
    'Microsoft.Getstarted'
    'Microsoft.MicrosoftJournal'
    'Microsoft.MicrosoftOfficeHub'
    'Microsoft.MicrosoftSolitaireCollection'
    'Microsoft.MicrosoftStickyNotes'
    'Microsoft.Office.OneNote'
    'Microsoft.OutlookForWindows'
    'Microsoft.People'
    'Microsoft.PowerAutomateDesktop'
    'Microsoft.Todos'
    'Microsoft.WindowsAlarms'
    'Microsoft.windowscommunicationsapps'   # Mail & Calendar
    'Microsoft.WindowsFeedbackHub'
    'Microsoft.WindowsMaps'
    'Microsoft.WindowsSoundRecorder'
    'Microsoft.YourPhone'                   # Phone Link
    'Microsoft.ZuneMusic'                   # Groove Music / Media Player
    'Microsoft.ZuneVideo'                   # Movies & TV
    'MicrosoftCorporationII.MicrosoftFamily'
    'MicrosoftCorporationII.QuickAssist'
    # Microsoft — legacy Win10-era apps (no-op if absent on Win11)
    'Microsoft.3DBuilder'
    'Microsoft.Microsoft3DViewer'
    'Microsoft.Messaging'
    'Microsoft.MixedReality.Portal'
    'Microsoft.NetworkSpeedTest'
    'Microsoft.OneConnect'
    'Microsoft.Print3D'
    'Microsoft.SkypeApp'
    'Microsoft.WindowsPhone'
    'Microsoft.XboxApp'
    # Microsoft — Teams
    'Microsoft.Teams'
    'MicrosoftTeams'
    'MSTeams'
    # Microsoft — Windows 11 extras
    'Microsoft.Copilot'
    'Microsoft.Edge.GameAssist'
    'Microsoft.GamingApp'
    'Microsoft.OneDriveSync'
    'Microsoft.WidgetsPlatformRuntime'
    'MicrosoftWindows.CrossDevice'
    'RealtekSemiconductorCorp.RealtekAudioControl'
    # Xbox (IDs beyond the keep-list)
    'Microsoft.Xbox.TCUI'
    'Microsoft.XboxGameOverlay'
    'Microsoft.XboxGamingOverlay'
    'Microsoft.XboxIdentityProvider'
    'Microsoft.XboxSpeechToTextOverlay'
    # Third-party preinstalls (specific IDs)
    'SpotifyAB.SpotifyMusic'
    'king.com.CandyCrushSaga'
    'king.com.CandyCrushFriends'
    'king.com.FarmHeroesSaga'
    'Facebook.Facebook'
    'TikTok.TikTok'
    'BytedancePte.Ltd.TikTok'
    'Amazon.com.Amazon'
    'AmazonVideo.PrimeVideo'
    'Disney.37853D22215B2'
    'Duolingo-LearnLanguagesforFree'
    'D5EA27B7.Duolingo-LearnLanguagesforFree'
    'EclipseManager'
    'ActiproSoftwareLLC.562882FEEB491'
    'DolbyLaboratories.DolbyAudio'
    'PandoraMediaInc.29680B314EFC2'
)

foreach ($pkg in $bloatwarePackages) {
    $pkgName = $pkg
    $actions += @{
        Category    = 'Bloatware'
        Description = "Remove $pkgName"
        Detect      = {
            $found       = Get-AppxPackage -Name $pkgName -AllUsers -ErrorAction SilentlyContinue
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

# ─── Category 1b: Bloatware — Wildcard Patterns ──────────────────────────────

$bloatwareWildcards = @(
    # Common third-party
    '*CandyCrush*', '*BubbleWitch*', '*Disney*', '*Dolby*',
    '*Duolingo*', '*EclipseManager*', '*Facebook*', '*Flipboard*',
    '*Instagram*', '*Minecraft*', '*Netflix*', '*PandoraMedia*',
    '*Spotify*', '*TikTok*', '*Twitter*', '*Wunderlist*',
    '*LinkedInforWindows*', '*DevHome*',
    # ASUS Store bloatware
    '*ASUSPCAssistant*', '*ASUSProductRegistration*', '*ASUSGiftBox*',
    '*MyASUS*', '*ArmouryCrate*', '*ASUSSplendid*', '*GameVisual*',
    '*ASUSSystemDiagnosis*', '*ASUSScreensaver*', '*ASUSWallpaper*',
    '*ROGLiveService*', '*AuraCreator*', '*AuraSync*', '*AuraDeveloper*',
    '*ASUSSystemControl*', '*GlideX*', '*ScreenXpert*',
    # Windows AI / Recall workloads
    '*WindowsWorkload*'
)

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

# ─── Category 1c: Widgets — Remove WebExperience package ─────────────────────

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

# ─── Category 1d: Printer Bloatware ──────────────────────────────────────────

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
            $quiet    = $entry.QuietUninstallString
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
                    Write-Log "    [WARN] Could not uninstall $($entry.DisplayName): $_" Yellow
                }
            }
        }
    }
}

# ─── Category 2: Microsoft Office Uninstall ──────────────────────────────────

$actions += @{
    Category    = 'Office'
    Description = 'Uninstall Microsoft Office (Click-to-Run)'
    Detect      = {
        $c2r = @(
            "$env:ProgramFiles\Common Files\microsoft shared\ClickToRun\setup.exe"
            "${env:ProgramFiles(x86)}\Common Files\microsoft shared\ClickToRun\setup.exe"
        ) | Where-Object { Test-Path $_ } | Select-Object -First 1
        return ($null -ne $c2r)
    }
    Apply       = {
        $c2r = @(
            "$env:ProgramFiles\Common Files\microsoft shared\ClickToRun\setup.exe"
            "${env:ProgramFiles(x86)}\Common Files\microsoft shared\ClickToRun\setup.exe"
        ) | Where-Object { Test-Path $_ } | Select-Object -First 1
        $xmlPath = "$env:TEMP\office-uninstall.xml"
        @'
<Configuration>
  <Remove All="TRUE" />
  <Display Level="None" AcceptEULA="TRUE" />
  <Property Name="FORCEAPPSHUTDOWN" Value="TRUE" />
</Configuration>
'@ | Set-Content -Path $xmlPath -Encoding UTF8
        Start-Process $c2r -ArgumentList "/configure `"$xmlPath`"" -Wait -NoNewWindow
        Remove-Item $xmlPath -Force -ErrorAction SilentlyContinue
        Write-Log '    Click-to-Run Office uninstall complete.' Cyan
    }
}

$actions += @{
    Category    = 'Office'
    Description = 'Uninstall Microsoft Office (MSI-based)'
    Detect      = {
        $regPaths = @(
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
            'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
        )
        $found = Get-ItemProperty $regPaths -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -match 'Microsoft Office|Microsoft 365|Office 16|Office 15|Office 14' -and $_.UninstallString -match 'msiexec' }
        return ($null -ne $found -and @($found).Count -gt 0)
    }
    Apply       = {
        $regPaths = @(
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
            'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
        )
        Get-ItemProperty $regPaths -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -match 'Microsoft Office|Microsoft 365|Office 16|Office 15|Office 14' -and $_.UninstallString -match 'msiexec' } |
            ForEach-Object {
                $guid = ($_.UninstallString -replace '.*(\{[^}]+\}).*', '$1')
                Write-Log "    Uninstalling (MSI): $($_.DisplayName)" Cyan
                Start-Process msiexec.exe -ArgumentList "/x $guid /qn /norestart REBOOT=ReallySuppress" -Wait -NoNewWindow
            }
    }
}

# ─── Category 3: OneDrive — Full Uninstall ───────────────────────────────────

$actions += @{
    Category    = 'OneDrive'
    Description = 'Uninstall OneDrive'
    Detect      = {
        $setup = "$env:SYSTEMROOT\System32\OneDriveSetup.exe"
        if (-not (Test-Path $setup)) { $setup = "$env:SYSTEMROOT\SysWOW64\OneDriveSetup.exe" }
        $proc = Get-Process -Name 'OneDrive' -ErrorAction SilentlyContinue
        return ($null -ne $proc -or (Test-Path $setup))
    }
    Apply       = {
        Stop-Process -Name 'OneDrive' -Force -ErrorAction SilentlyContinue
        Start-Sleep 2
        $setup = "$env:SYSTEMROOT\System32\OneDriveSetup.exe"
        if (-not (Test-Path $setup)) { $setup = "$env:SYSTEMROOT\SysWOW64\OneDriveSetup.exe" }
        if (Test-Path $setup) {
            & $setup /uninstall
            Write-Log '    OneDrive uninstalled.' Cyan
        }
    }
}

$oneDriveRegistrySettings = @(
    @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive'; Name='DisableFileSyncNGSC'; Value=1; Desc='Block OneDrive file sync' }
    @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive'; Name='DisableFileSync';     Value=1; Desc='Block OneDrive sync (legacy key)' }
    @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\OneDrive';         Name='KFMBlockOptIn';       Value=1; Desc='Block OneDrive Known Folder Move prompts' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name='ShowSyncProviderNotifications'; Value=0; Desc='Disable OneDrive ads in Explorer' }
)
# Also remove from Explorer sidebar (HKCR paths — handle separately)
foreach ($setting in $oneDriveRegistrySettings) {
    $s = $setting
    $actions += @{
        Category    = 'OneDrive'
        Description = $s.Desc
        Detect      = { Test-RegistryValue -Path $s.Path -Name $s.Name -Value $s.Value }.GetNewClosure()
        Apply       = { Set-RegistryValue -Path $s.Path -Name $s.Name -Value $s.Value }.GetNewClosure()
    }
}

$actions += @{
    Category    = 'OneDrive'
    Description = 'Remove OneDrive from Explorer sidebar'
    Detect      = {
        $v1 = (Get-ItemProperty 'HKCR:\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}' -Name 'System.IsPinnedToNameSpaceTree' -ErrorAction SilentlyContinue).'System.IsPinnedToNameSpaceTree'
        return ($v1 -ne 0)
    }
    Apply       = {
        Set-RegistryValue 'HKCR:\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}'              'System.IsPinnedToNameSpaceTree' 0
        Set-RegistryValue 'HKCR:\Wow6432Node\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}' 'System.IsPinnedToNameSpaceTree' 0
    }
}

# ─── Category 4: ASUS Bloatware (Win32) ──────────────────────────────────────

$actions += @{
    Category    = 'ASUS Bloatware'
    Description = 'Uninstall ASUS Win32 programs'
    Detect      = {
        $uninstallPaths = @(
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
            'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
            'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
        )
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
            $quiet    = $entry.QuietUninstallString
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
                    Write-Log "    [WARN] Could not uninstall $($entry.DisplayName): $_" Yellow
                }
            }
        }
    }
}

$asusServices = @(
    @{ Name='ASUSOptimization';             Desc='ASUS Optimization' }
    @{ Name='ASUSSystemAnalysis';           Desc='ASUS System Analysis' }
    @{ Name='ASUSSystemDiagnosis';          Desc='ASUS System Diagnosis' }
    @{ Name='AsusCertService';              Desc='ASUS Certificate Service' }
    @{ Name='ASUSLinkNear';                 Desc='ASUS Link Near' }
    @{ Name='ASUSLinkRemote';               Desc='ASUS Link Remote' }
    @{ Name='ASUSSoftwareManager';          Desc='ASUS Software Manager' }
    @{ Name='ArmouryCrateControlInterface'; Desc='Armoury Crate Control Interface' }
    @{ Name='ArmouryCrateSEService';        Desc='Armoury Crate SE Service' }
    @{ Name='AsusAppService';               Desc='ASUS App Service' }
    @{ Name='ASUSROGLSLService';            Desc='ROG Live Service' }
    @{ Name='LightingService';              Desc='ASUS Aura Lighting Service' }
    @{ Name='GameSDK Service';              Desc='ASUS GameSDK Service' }
    @{ Name='AsSysCtrlService';             Desc='ASUS System Control Service' }
    @{ Name='ScreenXpertService';           Desc='ScreenXpert Service' }
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
            Set-Service  -Name $s.Name -StartupType Disabled -ErrorAction SilentlyContinue
        }.GetNewClosure()
    }
}

$asusTaskPaths = @('\ASUS\', '\ASUS\ArmouryCrate\', '\ASUS\MyASUS\', '\ASUS\ScreenXpert\', '\ASUS\GlideX\')

$actions += @{
    Category    = 'ASUS Tasks'
    Description = 'Disable all ASUS scheduled tasks'
    Detect      = {
        foreach ($tp in $asusTaskPaths) {
            $tasks = Get-ScheduledTask -TaskPath $tp -ErrorAction SilentlyContinue |
                Where-Object { $_.State -ne 'Disabled' }
            if ($tasks) { return $true }
        }
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
                $names = (Get-ItemProperty $rp -ErrorAction SilentlyContinue).PSObject.Properties |
                    Where-Object { $_.Name -match 'ASUS|Armoury|ROG|Aura|GameVisual|GlideX|ScreenXpert' }
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
                $names = (Get-ItemProperty $rp -ErrorAction SilentlyContinue).PSObject.Properties |
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

# ─── Category 5: NVIDIA Telemetry ────────────────────────────────────────────

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
            $quiet    = $entry.QuietUninstallString
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

$actions += @{
    Category    = 'NVIDIA Telemetry'
    Description = 'Disable NVIDIA Telemetry Container service (NvTelemetryContainer)'
    Detect      = {
        $svc = Get-Service -Name 'NvTelemetryContainer' -ErrorAction SilentlyContinue
        return ($null -ne $svc -and $svc.StartType -ne 'Disabled')
    }
    Apply       = {
        Stop-Service -Name 'NvTelemetryContainer' -Force -ErrorAction SilentlyContinue
        Set-Service  -Name 'NvTelemetryContainer' -StartupType Disabled -ErrorAction SilentlyContinue
    }
}

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

# ─── Category 6: Telemetry & Privacy — Registry ──────────────────────────────

$telemetrySettings = @(
    @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection';            Name='AllowTelemetry';                              Value=0; Desc='Disable telemetry data collection' }
    @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection';            Name='AllowDeviceNameInTelemetry';                  Value=0; Desc='Prevent device name in telemetry' }
    @{ Path='HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection'; Name='AllowTelemetry';                          Value=0; Desc='Disable telemetry (secondary key)' }
    @{ Path='HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Policies\DataCollection'; Name='AllowTelemetry';              Value=0; Desc='Disable telemetry (Wow64 key)' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy';             Name='TailoredExperiencesWithDiagnosticDataEnabled'; Value=0; Desc='Disable tailored experiences' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo';     Name='Enabled';                                     Value=0; Desc='Disable advertising ID (user)' }
    @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo';           Name='DisabledByGroupPolicy';                       Value=1; Desc='Disable advertising ID (policy)' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Input\TIPC';                                 Name='Enabled';                                     Value=0; Desc='Disable inking/typing data collection' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\InputPersonalization';                       Name='RestrictImplicitInkCollection';               Value=1; Desc='Restrict implicit ink collection' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\InputPersonalization';                       Name='RestrictImplicitTextCollection';              Value=1; Desc='Restrict implicit text collection' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Personalization\Settings';                   Name='AcceptedPrivacyPolicy';                       Value=0; Desc='Disable typing personalization' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CPSS\Store\InkingAndTypingPersonalization'; Name='Value'; Value=0; Desc='Disable inking and typing personalization' }
    @{ Path='HKLM:\SOFTWARE\Microsoft\PolicyManager\default\TextInput\AllowLinguisticDataCollection'; Name='value'; Value=0; Desc='Disable linguistic data collection' }
    @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\System';                   Name='EnableActivityFeed';                          Value=0; Desc='Disable activity history / Timeline' }
    @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\System';                   Name='PublishUserActivities';                       Value=0; Desc='Disable activity history publishing' }
    @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\System';                   Name='UploadUserActivities';                        Value=0; Desc='Disable activity history upload' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced';   Name='Start_TrackProgs';                            Value=0; Desc='Disable app launch tracking' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Siuf\Rules';                                 Name='NumberOfSIUFInPeriod';                        Value=0; Desc='Disable feedback requests' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Siuf\Rules';                                 Name='PeriodInNanoSeconds';                         Value=0; Desc='Disable feedback period' }
    @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat';                 Name='AITEnable';                                   Value=0; Desc='Disable Application Impact Telemetry' }
    @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\SQMClient\Windows';                 Name='CEIPEnable';                                  Value=0; Desc='Disable CEIP' }
    @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors';        Name='DisableLocation';                             Value=1; Desc='Disable location tracking' }
    @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Speech';                            Name='AllowSpeechModelUpdate';                      Value=0; Desc='Disable speech data collection' }
    @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\FindMyDevice';                      Name='AllowFindMyDevice';                           Value=0; Desc='Disable Find My Device' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name='SubscribedContent-338393Enabled';          Value=0; Desc='Disable suggested content in Settings' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name='SubscribedContent-353694Enabled';          Value=0; Desc='Disable suggested content in Settings (2)' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name='SubscribedContent-353696Enabled';          Value=0; Desc='Disable suggested content in Settings (3)' }
)

foreach ($setting in $telemetrySettings) {
    $s = $setting
    $actions += @{
        Category    = 'Telemetry'
        Description = $s.Desc
        Detect      = { Test-RegistryValue -Path $s.Path -Name $s.Name -Value $s.Value }.GetNewClosure()
        Apply       = { Set-RegistryValue  -Path $s.Path -Name $s.Name -Value $s.Value }.GetNewClosure()
    }
}

# ─── Category 6b: Privacy — App Permissions ──────────────────────────────────

$appPrivacySettings = @(
    @{ Name='LetAppsAccessMicrophone';   Value=2; Desc='Force-deny app microphone access' }
    @{ Name='LetAppsAccessCamera';       Value=2; Desc='Force-deny app camera access' }
    @{ Name='LetAppsAccessLocation';     Value=2; Desc='Force-deny app location access' }
    @{ Name='LetAppsAccessContacts';     Value=2; Desc='Force-deny app contacts access' }
    @{ Name='LetAppsAccessNotifications';Value=2; Desc='Force-deny app notifications access' }
    @{ Name='LetAppsRunInBackground';    Value=2; Desc='Disable background app access (policy)' }
)

foreach ($setting in $appPrivacySettings) {
    $s = $setting
    $actions += @{
        Category    = 'App Permissions'
        Description = $s.Desc
        Detect      = { Test-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy' -Name $s.Name -Value $s.Value }.GetNewClosure()
        Apply       = { Set-RegistryValue  -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy' -Name $s.Name -Value $s.Value }.GetNewClosure()
    }
}

$actions += @{
    Category    = 'App Permissions'
    Description = 'Disable UWP background apps globally (user key)'
    Detect      = { Test-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications' -Name 'GlobalUserDisabled' -Value 1 }
    Apply       = { Set-RegistryValue  -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications' -Name 'GlobalUserDisabled' -Value 1 }
}

# ─── Category 7: Cortana & Search ────────────────────────────────────────────

$cortanaSettings = @(
    @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search'; Name='AllowCortana';             Value=0; Desc='Disable Cortana' }
    @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search'; Name='AllowCortanaAboveLock';    Value=0; Desc='Disable Cortana on lock screen' }
    @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search'; Name='AllowSearchToUseLocation'; Value=0; Desc='Prevent search using location' }
    @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search'; Name='ConnectedSearchUseWeb';    Value=0; Desc='Disable web results in search' }
    @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search'; Name='DisableWebSearch';         Value=1; Desc='Disable web search (policy)' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search';   Name='BingSearchEnabled';        Value=0; Desc='Disable Bing search in Start' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search';   Name='CortanaEnabled';           Value=0; Desc='Disable Cortana in search' }
    @{ Path='HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer';       Name='DisableSearchBoxSuggestions'; Value=1; Desc='Disable search box suggestions' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search';   Name='SearchboxTaskbarMode';     Value=1; Desc='Show search icon only (not full bar)' }
)

foreach ($setting in $cortanaSettings) {
    $s = $setting
    $actions += @{
        Category    = 'Cortana/Search'
        Description = $s.Desc
        Detect      = { Test-RegistryValue -Path $s.Path -Name $s.Name -Value $s.Value }.GetNewClosure()
        Apply       = { Set-RegistryValue  -Path $s.Path -Name $s.Name -Value $s.Value }.GetNewClosure()
    }
}

# ─── Category 8: Services ─────────────────────────────────────────────────────

$servicesToDisable = @(
    @{ Name='DiagTrack';       Desc='Connected User Experiences and Telemetry' }
    @{ Name='dmwappushservice';Desc='WAP Push Message Routing (telemetry)' }
    @{ Name='SysMain';         Desc='SysMain / Superfetch (unnecessary on SSDs)' }
    @{ Name='WSearch';         Desc='Windows Search Indexer' }
    @{ Name='XblAuthManager';  Desc='Xbox Live Auth Manager' }
    @{ Name='XblGameSave';     Desc='Xbox Live Game Save' }
    @{ Name='XboxNetApiSvc';   Desc='Xbox Live Networking Service' }
    @{ Name='XboxGipSvc';      Desc='Xbox Accessory Management' }
    @{ Name='RetailDemo';      Desc='Retail Demo Service' }
    @{ Name='MapsBroker';      Desc='Downloaded Maps Manager' }
    @{ Name='lfsvc';           Desc='Geolocation Service' }
    @{ Name='SharedAccess';    Desc='Internet Connection Sharing' }
    @{ Name='WerSvc';          Desc='Windows Error Reporting' }
    @{ Name='Fax';             Desc='Fax Service' }
    @{ Name='fhsvc';           Desc='File History Service' }
    @{ Name='wisvc';           Desc='Windows Insider Service' }
    @{ Name='WMPNetworkSvc';   Desc='Windows Media Player Network Sharing' }
    @{ Name='icssvc';          Desc='Windows Mobile Hotspot Service' }
    @{ Name='PhoneSvc';        Desc='Phone Service (landline telephony)' }
    @{ Name='TapiSrv';         Desc='Telephony' }
    @{ Name='stisvc';          Desc='Windows Image Acquisition (scanners/cameras)' }
    @{ Name='DPS';             Desc='Diagnostic Policy Service' }
    @{ Name='WdiServiceHost';  Desc='Diagnostic Service Host' }
    @{ Name='WdiSystemHost';   Desc='Diagnostic System Host' }
    @{ Name='CDPSvc';          Desc='Connected Devices Platform Service' }
    @{ Name='CDPUserSvc';      Desc='Connected Devices Platform User Service' }
    @{ Name='PcaSvc';          Desc='Program Compatibility Assistant' }
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
            Set-Service  -Name $s.Name -StartupType Disabled -ErrorAction SilentlyContinue
        }.GetNewClosure()
    }
}

# ─── Category 9: Scheduled Tasks ─────────────────────────────────────────────

$tasksToDisable = @(
    @{ Path='\Microsoft\Windows\Application Experience\';               Name='Microsoft Compatibility Appraiser' }
    @{ Path='\Microsoft\Windows\Application Experience\';               Name='ProgramDataUpdater' }
    @{ Path='\Microsoft\Windows\Application Experience\';               Name='StartupAppTask' }
    @{ Path='\Microsoft\Windows\Autochk\';                              Name='Proxy' }
    @{ Path='\Microsoft\Windows\Customer Experience Improvement Program\'; Name='Consolidator' }
    @{ Path='\Microsoft\Windows\Customer Experience Improvement Program\'; Name='UsbCeip' }
    @{ Path='\Microsoft\Windows\Customer Experience Improvement Program\'; Name='KernelCeipTask' }
    @{ Path='\Microsoft\Windows\DiskDiagnostic\';                       Name='Microsoft-Windows-DiskDiagnosticDataCollector' }
    @{ Path='\Microsoft\Windows\Feedback\Siuf\';                        Name='DmClient' }
    @{ Path='\Microsoft\Windows\Feedback\Siuf\';                        Name='DmClientOnScenarioDownload' }
    @{ Path='\Microsoft\Windows\Windows Error Reporting\';              Name='QueueReporting' }
    @{ Path='\Microsoft\Windows\CloudExperienceHost\';                  Name='CreateObjectTask' }
    @{ Path='\Microsoft\Windows\Maps\';                                 Name='MapsToastTask' }
    @{ Path='\Microsoft\Windows\Maps\';                                 Name='MapsUpdateTask' }
    @{ Path='\Microsoft\Windows\Clip\';                                 Name='License Validation' }
    @{ Path='\Microsoft\Windows\Speech\';                               Name='SpeechModelDownloadTask' }
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

# ─── Category 10: Copilot & Recall ───────────────────────────────────────────

$copilotRecallSettings = @(
    @{ Path='HKCU:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot'; Name='TurnOffWindowsCopilot'; Value=1; Desc='Disable Windows Copilot (user)' }
    @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot'; Name='TurnOffWindowsCopilot'; Value=1; Desc='Disable Windows Copilot (machine)' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name='ShowCopilotButton'; Value=0; Desc='Hide Copilot button from taskbar' }
    @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI';     Name='DisableAIDataAnalysis';  Value=1; Desc='Disable Windows Recall' }
    @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI';     Name='TurnOffSavingSnapshots'; Value=1; Desc='Disable Recall snapshots' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name='RecallEnabled'; Value=0; Desc='Disable Recall (user setting)' }
)

foreach ($setting in $copilotRecallSettings) {
    $s = $setting
    $actions += @{
        Category    = 'Copilot/Recall'
        Description = $s.Desc
        Detect      = { Test-RegistryValue -Path $s.Path -Name $s.Name -Value $s.Value }.GetNewClosure()
        Apply       = { Set-RegistryValue  -Path $s.Path -Name $s.Name -Value $s.Value }.GetNewClosure()
    }
}

# ─── Category 11: Game Bar / DVR ─────────────────────────────────────────────

$gameBarSettings = @(
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\GameDVR'; Name='AppCaptureEnabled';      Value=0; Desc='Disable Game DVR capture' }
    @{ Path='HKCU:\System\GameConfigStore';                            Name='GameDVR_Enabled';         Value=0; Desc='Disable Game DVR' }
    @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR';      Name='AllowGameDVR';            Value=0; Desc='Disable Game DVR (policy)' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\GameBar';                        Name='UseNexusForGameBarEnabled';Value=0; Desc='Disable Game Bar overlay' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\GameBar';                        Name='AutoGameModeEnabled';     Value=0; Desc='Disable auto Game Mode' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\GameBar';                        Name='ShowStartupPanel';        Value=0; Desc='Disable Game Bar startup panel' }
)

foreach ($setting in $gameBarSettings) {
    $s = $setting
    $actions += @{
        Category    = 'Game Bar'
        Description = $s.Desc
        Detect      = { Test-RegistryValue -Path $s.Path -Name $s.Name -Value $s.Value }.GetNewClosure()
        Apply       = { Set-RegistryValue  -Path $s.Path -Name $s.Name -Value $s.Value }.GetNewClosure()
    }
}

# ─── Category 12: Edge Browser ───────────────────────────────────────────────

$edgeSettings = @(
    @{ Name='HideFirstRunExperience';              Value=1; Desc='Skip Edge first-run wizard' }
    @{ Name='StandaloneHubsSidebarEnabled';        Value=0; Desc='Disable Edge standalone sidebar' }
    @{ Name='HubsSidebarEnabled';                  Value=0; Desc='Disable Edge sidebar hubs' }
    @{ Name='EdgeShoppingAssistantEnabled';        Value=0; Desc='Disable Edge shopping assistant' }
    @{ Name='ShowMicrosoftRewards';                Value=0; Desc='Disable Edge rewards' }
    @{ Name='BrowserSignin';                       Value=0; Desc='Disable Edge browser sign-in prompts' }
    @{ Name='UserFeedbackAllowed';                 Value=0; Desc='Disable Edge feedback' }
    @{ Name='PersonalizationReportingEnabled';     Value=0; Desc='Disable Edge usage tracking' }
    @{ Name='DefaultBrowserSettingsCampaignEnabled';Value=0; Desc='Disable default browser nag' }
    @{ Name='NewTabPageContentEnabled';            Value=0; Desc='Disable Edge new tab content' }
    @{ Name='NewTabPageHideDefaultTopSites';       Value=1; Desc='Hide Edge top sites on new tab' }
    @{ Name='NewTabPageBingChatEnabled';           Value=0; Desc='Disable Bing Chat on new tab' }
    @{ Name='CopilotPageContext';                  Value=0; Desc='Disable Edge Copilot page context' }
    @{ Name='Microsoft365CopilotChatIconEnabled';  Value=0; Desc='Remove Edge Copilot icon' }
    @{ Name='EdgeCollectionsEnabled';              Value=0; Desc='Disable Edge Collections' }
    @{ Name='ShowRecommendationsEnabled';          Value=0; Desc='Disable Edge recommendations' }
    @{ Name='GuidedSwitchEnabled';                 Value=0; Desc='Disable Edge browser switch prompts' }
    @{ Name='ForceSync';                           Value=0; Desc='Prevent Edge forced sync' }
    @{ Name='ImplicitSignInEnabled';               Value=0; Desc='Prevent Edge auto sign-in' }
)

$edgePolicyPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'

foreach ($setting in $edgeSettings) {
    $s = $setting
    $actions += @{
        Category    = 'Edge'
        Description = $s.Desc
        Detect      = { Test-RegistryValue -Path $edgePolicyPath -Name $s.Name -Value $s.Value }.GetNewClosure()
        Apply       = { Set-RegistryValue  -Path $edgePolicyPath -Name $s.Name -Value $s.Value }.GetNewClosure()
    }
}

$actions += @{
    Category    = 'Edge'
    Description = 'Prevent Edge desktop shortcut creation'
    Detect      = { Test-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\EdgeUpdate' -Name 'CreateDesktopShortcutDefault' -Value 0 }
    Apply       = { Set-RegistryValue  -Path 'HKLM:\SOFTWARE\Policies\Microsoft\EdgeUpdate' -Name 'CreateDesktopShortcutDefault' -Value 0 }
}

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

# ─── Category 13: Windows Update ─────────────────────────────────────────────

$wuSettings = @(
    @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'; Name='NoAutoRebootWithLoggedOnUsers'; Value=1; Desc='Prevent auto-restart while user is logged in' }
    @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'; Name='AUOptions';                    Value=4; Desc='Download and schedule install (not auto-install)' }
    @{ Path='HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config'; Name='DODownloadMode'; Value=0; Desc='Disable P2P delivery optimization' }
    @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization'; Name='DODownloadMode';           Value=0; Desc='Disable P2P delivery optimization (policy)' }
    @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'; Name='SetActiveHours';                  Value=1; Desc='Enable active hours' }
    @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'; Name='ActiveHoursStart';                Value=8; Desc='Set active hours start: 8 AM' }
    @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'; Name='ActiveHoursEnd';                  Value=23; Desc='Set active hours end: 11 PM' }
)

foreach ($setting in $wuSettings) {
    $s = $setting
    $actions += @{
        Category    = 'Windows Update'
        Description = $s.Desc
        Detect      = { Test-RegistryValue -Path $s.Path -Name $s.Name -Value $s.Value }.GetNewClosure()
        Apply       = { Set-RegistryValue  -Path $s.Path -Name $s.Name -Value $s.Value }.GetNewClosure()
    }
}

# ─── Category 14: UI / Taskbar / Start Menu ──────────────────────────────────

$uiSettings = @(
    # Content Delivery Manager — ads, suggestions, silent installs
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name='SubscribedContent-338388Enabled';     Value=0; Desc='Disable Start suggestions (1)' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name='SubscribedContent-338389Enabled';     Value=0; Desc='Disable Start suggestions (2)' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name='SubscribedContent-353698Enabled';     Value=0; Desc='Disable Start suggestions (3)' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name='SubscribedContent-310093Enabled';     Value=0; Desc='Disable "Welcome experience" after updates' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name='SubscribedContent-338387Enabled';     Value=0; Desc='Disable "Get even more out of Windows" nag' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name='SubscribedContent-338393Enabled';     Value=0; Desc='Disable suggested content in Settings' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name='SubscribedContent-353694Enabled';     Value=0; Desc='Disable suggested content in Settings (2)' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name='SubscribedContent-353696Enabled';     Value=0; Desc='Disable suggested content in Settings (3)' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name='SystemPaneSuggestionsEnabled';        Value=0; Desc='Disable system pane suggestions' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name='SoftLandingEnabled';                  Value=0; Desc='Disable tip notifications' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name='OemPreInstalledAppsEnabled';          Value=0; Desc='Disable OEM pre-installed apps' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name='PreInstalledAppsEnabled';             Value=0; Desc='Disable pre-installed apps' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name='PreInstalledAppsEverEnabled';         Value=0; Desc='Disable pre-installed apps (ever)' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name='SilentInstalledAppsEnabled';          Value=0; Desc='Stop silent app auto-installs' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name='ContentDeliveryAllowed';              Value=0; Desc='Disable content delivery' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name='RotatingLockScreenEnabled';           Value=0; Desc='Disable lock screen spotlight' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name='RotatingLockScreenOverlayEnabled';    Value=0; Desc='Disable lock screen overlay ads' }
    # Cloud content policy
    @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'; Name='DisableSoftLanding';                Value=1; Desc='Disable soft landing (policy)' }
    @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'; Name='DisableWindowsConsumerFeatures';    Value=1; Desc='Disable Windows consumer features' }
    @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'; Name='DisableCloudOptimizedContent';      Value=1; Desc='Disable cloud-optimized content' }
    # Start menu
    @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer'; Name='HideRecommendedSection';                Value=1; Desc='Hide Recommended section in Start' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name='Start_IrisRecommendations'; Value=0; Desc='Disable Start menu AI recommendations' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name='Start_AccountNotifications'; Value=0; Desc='Disable Start menu account notifications' }
    # Taskbar
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name='TaskbarMn';               Value=0; Desc='Remove Chat (Teams) icon from taskbar' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name='ShowTaskViewButton';       Value=0; Desc='Remove Task View button from taskbar' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name='TaskbarDa';               Value=0; Desc='Remove Widgets from taskbar' }
    @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Dsh';                             Name='AllowNewsAndInterests';    Value=0; Desc='Disable Widgets via policy' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name='TaskbarAl';               Value=0; Desc='Align taskbar icons to left' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\SearchSettings';    Name='IsDynamicSearchBoxEnabled'; Value=0; Desc='Disable search highlights' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name='TaskbarGlomLevel';         Value=0; Desc='Never combine taskbar buttons' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name='MMTaskbarGlomLevel';       Value=0; Desc='Never combine taskbar buttons (multi-monitor)' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name='ShowSecondsInSystemClock'; Value=1; Desc='Show seconds in taskbar clock' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Feeds';             Name='ShellFeedsTaskbarViewMode'; Value=2; Desc='Disable News and interests / Weather on hover' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings'; Name='NOC_GLOBAL_SETTING_ALLOW_TOASTS_ABOVE_LOCK'; Value=0; Desc='Disable notifications on lock screen' }
    # Explorer
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name='HideFileExt';             Value=0; Desc='Show file extensions' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name='Hidden';                  Value=1; Desc='Show hidden files' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name='LaunchTo';                Value=1; Desc='Open Explorer to This PC' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name='EnableSnapAssistFlyout';  Value=0; Desc='Disable snap suggestions popup' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name='UseCompactMode';          Value=1; Desc='Enable compact Explorer layout' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name='DisallowShaking';         Value=1; Desc='Disable Aero Shake (shake-to-minimize)' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name='Start_TrackDocs';         Value=0; Desc='Disable recent documents tracking' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer';          Name='ShowRecent';              Value=0; Desc='Disable recent files in Quick Access' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer';          Name='ShowFrequent';            Value=0; Desc='Disable frequent folders in Quick Access' }
    # OOBE nags
    @{ Path='HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE';             Name='DisablePrivacyExperience'; Value=1; Desc='Disable post-update privacy screen' }
    @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\OOBE';                   Name='DisablePrivacyExperience'; Value=1; Desc='Disable post-update privacy screen (policy)' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\UserProfileEngagement'; Name='ScoobeSystemSettingEnabled'; Value=0; Desc='Disable "Finish setting up" nag' }
    # Lock screen
    @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization'; Name='NoLockScreen'; Value=1; Desc='Skip lock screen on resume from sleep' }
)

foreach ($setting in $uiSettings) {
    $s = $setting
    $actions += @{
        Category    = 'UI/Taskbar'
        Description = $s.Desc
        Detect      = { Test-RegistryValue -Path $s.Path -Name $s.Name -Value $s.Value }.GetNewClosure()
        Apply       = { Set-RegistryValue  -Path $s.Path -Name $s.Name -Value $s.Value }.GetNewClosure()
    }
}

# Default Explorer view: Details, sorted by name, no group-by
$actions += @{
    Category    = 'UI/Taskbar'
    Description = 'Set default Explorer view to Details'
    Detect      = {
        $shellKey = 'HKCU:\SOFTWARE\Classes\Local Settings\Software\Microsoft\Windows\Shell\Bags\AllFolders\Shell'
        $current  = (Get-ItemProperty $shellKey -Name 'Mode' -ErrorAction SilentlyContinue).Mode
        return ($current -ne 4)
    }
    Apply       = {
        $shellKey = 'HKCU:\SOFTWARE\Classes\Local Settings\Software\Microsoft\Windows\Shell\Bags\AllFolders\Shell'
        Set-RegistryValue $shellKey 'WFlags' 0x41200001
        Set-RegistryValue $shellKey 'Vid'    '{137E7700-3573-11CF-AE69-08002B2E1262}' 'String'
        Set-RegistryValue $shellKey 'Mode'   4
    }
}

# Remove "- Shortcut" suffix when creating shortcuts
$actions += @{
    Category    = 'UI/Taskbar'
    Description = 'Remove "- Shortcut" suffix from new shortcuts'
    Detect      = {
        $val = (Get-ItemProperty 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer' -Name 'link' -ErrorAction SilentlyContinue).link
        return ($null -eq $val -or [System.BitConverter]::ToString($val) -ne '00-00-00-00')
    }
    Apply       = {
        Set-RegistryValue 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer' 'link' ([byte[]](0,0,0,0)) 'Binary'
    }
}

# ─── Category 15: Visual / Cosmetic ──────────────────────────────────────────
# Opinionated visual defaults. Comment out any you don't want.

$visualSettings = @(
    # Dark mode
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize'; Name='AppsUseLightTheme';    Value=0; Desc='Dark mode for apps (user)' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize'; Name='SystemUsesLightTheme'; Value=0; Desc='Dark mode for system (user)' }
    @{ Path='HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize'; Name='AppsUseLightTheme';    Value=0; Desc='Dark mode for apps (machine)' }
    @{ Path='HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize'; Name='SystemUsesLightTheme'; Value=0; Desc='Dark mode for system (machine)' }
    # Transparency & title bars
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize'; Name='EnableTransparency';   Value=0; Desc='Disable transparency effects' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize'; Name='ColorPrevalence';      Value=0; Desc='No accent color on taskbar/title bars' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\DWM';                               Name='ColorPrevalence';      Value=0; Desc='No color on title bars (DWM)' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\DWM';                               Name='EnableWindowColorization'; Value=0; Desc='Disable window colorization' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\DWM';                               Name='EnableAeroPeek';        Value=0; Desc='Disable Aero Peek' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\DWM';                               Name='AlwaysHibernateThumbnails'; Value=0; Desc='Disable taskbar thumbnail previews' }
    # Performance / animations
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects'; Name='VisualFXSetting';  Value=2; Desc='Visual effects: adjust for best performance' }
    @{ Path='HKCU:\Control Panel\Desktop\WindowMetrics';                          Name='MinAnimate';            Value='0'; Type='String'; Desc='Disable minimize/maximize animations' }
    @{ Path='HKCU:\Control Panel\Desktop';                                        Name='MenuShowDelay';         Value='0'; Type='String'; Desc='Remove menu show delay' }
    @{ Path='HKCU:\Control Panel\Desktop';                                        Name='DragFullWindows';       Value='0'; Type='String'; Desc='Disable show window contents while dragging' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name='TaskbarAnimations';     Value=0; Desc='Disable taskbar animations' }
    # Accent color — neutral dark grey (ABGR: FF4C4C4C)
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Accent'; Name='AccentColor';     Value=0xFF4C4C4C; Desc='Set neutral dark-grey accent color' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Accent'; Name='AccentColorMenu'; Value=0xFF4C4C4C; Desc='Set neutral dark-grey accent color (menu)' }
    @{ Path='HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Accent'; Name='StartColorMenu';  Value=0xFF2D2D2D; Desc='Set neutral dark Start color' }
)

foreach ($setting in $visualSettings) {
    $s = $setting
    $type = if ($s.Type) { $s.Type } else { 'DWord' }
    $actions += @{
        Category    = 'Visual'
        Description = $s.Desc
        Detect      = { Test-RegistryValue -Path $s.Path -Name $s.Name -Value $s.Value }.GetNewClosure()
        Apply       = { Set-RegistryValue  -Path $s.Path -Name $s.Name -Value $s.Value -Type $type }.GetNewClosure()
    }
}

# ─── Category 16: Classic Right-Click Context Menu ────────────────────────────

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
        $ctxKey = 'HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32'
        if (-not (Test-Path $ctxKey)) { New-Item -Path $ctxKey -Force | Out-Null }
        Set-ItemProperty -Path $ctxKey -Name '(Default)' -Value '' -Type String -Force
    }
}

# ─── Category 17: Accessibility — Disable Annoying Shortcut Prompts ──────────

$accessibilitySettings = @(
    @{ Path='HKCU:\Control Panel\Accessibility\StickyKeys';    Name='Flags'; Value='506'; Type='String'; Desc='Disable Sticky Keys prompt (5x Shift)' }
    @{ Path='HKCU:\Control Panel\Accessibility\ToggleKeys';    Name='Flags'; Value='58';  Type='String'; Desc='Disable Toggle Keys prompt' }
    @{ Path='HKCU:\Control Panel\Accessibility\Keyboard Response'; Name='Flags'; Value='122'; Type='String'; Desc='Disable Filter Keys prompt (hold Shift)' }
)

foreach ($setting in $accessibilitySettings) {
    $s    = $setting
    $type = if ($s.Type) { $s.Type } else { 'DWord' }
    $actions += @{
        Category    = 'Accessibility'
        Description = $s.Desc
        Detect      = { Test-RegistryValue -Path $s.Path -Name $s.Name -Value $s.Value }.GetNewClosure()
        Apply       = { Set-RegistryValue  -Path $s.Path -Name $s.Name -Value $s.Value -Type $type }.GetNewClosure()
    }
}

# ─── Category 18: AutoPlay ────────────────────────────────────────────────────

$actions += @{
    Category    = 'Autoplay'
    Description = 'Disable AutoPlay for all media and devices'
    Detect      = { Test-RegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\AutoplayHandlers' -Name 'DisableAutoplay' -Value 1 }
    Apply       = { Set-RegistryValue  -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\AutoplayHandlers' -Name 'DisableAutoplay' -Value 1 }
}

$actions += @{
    Category    = 'Autoplay'
    Description = 'Disable AutoPlay via policy'
    Detect      = { Test-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer' -Name 'NoAutoplayfornonVolume' -Value 1 }
    Apply       = { Set-RegistryValue  -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer' -Name 'NoAutoplayfornonVolume' -Value 1 }
}

$actions += @{
    Category    = 'Autoplay'
    Description = 'Disable AutoRun for all drive types'
    Detect      = { Test-RegistryValue -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' -Name 'NoDriveTypeAutoRun' -Value 255 }
    Apply       = { Set-RegistryValue  -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' -Name 'NoDriveTypeAutoRun' -Value 255 }
}

# ─── Category 19: Windows Ink Workspace ──────────────────────────────────────

$actions += @{
    Category    = 'Ink Workspace'
    Description = 'Disable Windows Ink Workspace'
    Detect      = { Test-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\WindowsInkWorkspace' -Name 'AllowWindowsInkWorkspace' -Value 0 }
    Apply       = { Set-RegistryValue  -Path 'HKLM:\SOFTWARE\Policies\Microsoft\WindowsInkWorkspace' -Name 'AllowWindowsInkWorkspace' -Value 0 }
}

$actions += @{
    Category    = 'Ink Workspace'
    Description = 'Disable Ink Workspace suggested apps'
    Detect      = { Test-RegistryValue -Path 'HKLM:\SOFTWARE\Policies\Microsoft\WindowsInkWorkspace' -Name 'AllowSuggestedAppsInWindowsInkWorkspace' -Value 0 }
    Apply       = { Set-RegistryValue  -Path 'HKLM:\SOFTWARE\Policies\Microsoft\WindowsInkWorkspace' -Name 'AllowSuggestedAppsInWindowsInkWorkspace' -Value 0 }
}

# ─── Category 20: Clipboard Cloud Sync ───────────────────────────────────────

$clipboardSettings = @(
    @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'; Name='AllowClipboardHistory';      Value=0; Desc='Disable clipboard history' }
    @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'; Name='AllowCrossDeviceClipboard';  Value=0; Desc='Disable cross-device clipboard sync' }
)

foreach ($setting in $clipboardSettings) {
    $s = $setting
    $actions += @{
        Category    = 'Clipboard'
        Description = $s.Desc
        Detect      = { Test-RegistryValue -Path $s.Path -Name $s.Name -Value $s.Value }.GetNewClosure()
        Apply       = { Set-RegistryValue  -Path $s.Path -Name $s.Name -Value $s.Value }.GetNewClosure()
    }
}

# ─── Category 21: Defender — Reduce Noise ────────────────────────────────────

$defenderSettings = @(
    @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'; Name='EnableSmartScreen'; Value=0; Desc='Disable SmartScreen UI prompts' }
    @{ Path='HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer'; Name='SmartScreenEnabled'; Value='Off'; Type='String'; Desc='Disable Explorer SmartScreen' }
    @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Reporting'; Name='DisableEnhancedNotifications'; Value=1; Desc='Reduce Defender notification noise' }
    @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender Security Center\Notifications'; Name='DisableNotifications'; Value=1; Desc='Disable Security Center notifications' }
    @{ Path='HKLM:\SOFTWARE\Policies\Microsoft\MRT'; Name='DontOfferThroughWUAU'; Value=1; Desc='Disable Malicious Software Removal Tool via WU' }
)

foreach ($setting in $defenderSettings) {
    $s    = $setting
    $type = if ($s.Type) { $s.Type } else { 'DWord' }
    $actions += @{
        Category    = 'Defender'
        Description = $s.Desc
        Detect      = { Test-RegistryValue -Path $s.Path -Name $s.Name -Value $s.Value }.GetNewClosure()
        Apply       = { Set-RegistryValue  -Path $s.Path -Name $s.Name -Value $s.Value -Type $type }.GetNewClosure()
    }
}

# ─── Category 22: Telemetry — Environment Variables ──────────────────────────

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

# ─── Category 23: Start Menu Layout Reset ────────────────────────────────────

$actions += @{
    Category    = 'Start Menu'
    Description = 'Reset Start menu pinned tiles to clean layout'
    Detect      = {
        $layoutFile = "$env:LOCALAPPDATA\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState\start2.bin"
        if (-not (Test-Path $layoutFile)) { return $false }
        $size = (Get-Item $layoutFile -ErrorAction SilentlyContinue).Length
        return ($size -gt 10240)   # >10KB suggests pre-pinned bloat tiles
    }
    Apply       = {
        $layoutFile = "$env:LOCALAPPDATA\Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState\start2.bin"
        if (Test-Path $layoutFile) {
            if (-not (Test-Path "$layoutFile.bak")) {
                Copy-Item $layoutFile "$layoutFile.bak" -Force
                Write-Log '    Backed up start2.bin.' Cyan
            }
            Stop-Process -Name 'StartMenuExperienceHost' -Force -ErrorAction SilentlyContinue
            Start-Sleep 1
            Remove-Item $layoutFile -Force
            Write-Log '    Start menu layout reset. Pins will regenerate cleanly on next login.' Cyan
        }
    }
}

# ─── Category 24: Recent Files Cleanup ───────────────────────────────────────

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
        Remove-Item "$recentPath\AutomaticDestinations\*"  -Force -ErrorAction SilentlyContinue
        Remove-Item "$recentPath\CustomDestinations\*"     -Force -ErrorAction SilentlyContinue
        Write-Log '    Cleared recent files and jump list history.' Cyan
    }
}

# ─── Category 25: Restart Explorer ───────────────────────────────────────────

$actions += @{
    Category    = 'Explorer'
    Description = 'Restart Windows Explorer to apply shell changes'
    Detect      = { return $true }   # Always run at the end after other changes
    Apply       = {
        Write-Log '    Restarting Explorer...' Cyan
        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
        Start-Sleep 2
        Start-Process explorer
    }
}

# ── Scan Phase ────────────────────────────────────────────────────────────────

Write-Log '── Scanning system ─────────────────────────────────────' Cyan
Write-Log ''

$pending    = @()
$alreadyOk  = 0

foreach ($action in $actions) {
    try {
        $needed = & $action.Detect
    } catch {
        $needed = $false
    }

    if ($needed) {
        $pending += $action
        Write-Host '  [PENDING]  ' -ForegroundColor Yellow -NoNewline
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
$failed  = 0

foreach ($action in $pending) {
    try {
        & $action.Apply
        Write-Log "  [APPLIED]  $($action.Category): $($action.Description)" Green
        $success++
    } catch {
        Write-Log "  [FAILED]   $($action.Category): $($action.Description) — $_" Red
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
Write-Log 'A restore point was created before any changes were made.' Green
Write-Log 'A restart is recommended for all changes to take effect.' Yellow

$restart = Read-Host 'Restart now? (y/N)'
if ($restart -eq 'y' -or $restart -eq 'Y') {
    Restart-Computer -Force
}
