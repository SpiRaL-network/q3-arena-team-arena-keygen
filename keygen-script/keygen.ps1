[CmdletBinding()]
param([switch]$SelfTest,[switch]$DetectOnly)

Set-StrictMode -Version 2.0
$appVersion = '1.0.0'
$keyChars = '237ABCDGHJLPRSTW'.ToCharArray()

function New-ArenaKey {
    (-join (1..16 | ForEach-Object { $keyChars | Get-Random })).ToLowerInvariant()
}

function Get-TeamArenaChecksum([string]$RawKey) {
    $sum = 0
    foreach ($character in $RawKey.ToCharArray()) { $sum += [int][char]$character }
    '{0:X2}' -f ($sum -band 0xFF)
}

function New-TeamArenaKey {
    $raw = -join (1..16 | ForEach-Object { $keyChars | Get-Random })
    '{0}-{1}-{2}-{3}-{4}' -f $raw.Substring(0,4), $raw.Substring(4,4), $raw.Substring(8,4), $raw.Substring(12,4), (Get-TeamArenaChecksum $raw)
}

function Get-RawTeamArenaKey([string]$DisplayKey) {
    $parts = $DisplayKey -split '-'
    if ($parts.Count -ne 5) { throw 'Invalid Team Arena key format.' }
    -join $parts[0..3]
}

function Write-KeyFile([string]$Path,[string]$Key) {
    $Key | Set-Content -LiteralPath $Path -Encoding ASCII -NoNewline
}

function Get-KeyInstallTargets([string]$GameRoot,[string]$ArenaKey,[string]$TeamArenaKey) {
    $targets = New-Object 'System.Collections.Generic.List[object]'
    $arenaDirectory = Join-Path $GameRoot 'baseq3'
    $teamDirectory = Join-Path $GameRoot 'missionpack'
    if ($ArenaKey -and (Test-Path -LiteralPath $arenaDirectory -PathType Container)) {
        $targets.Add([pscustomobject]@{ Game = 'Arena'; Path = (Join-Path $arenaDirectory 'q3key'); Key = $ArenaKey })
    }
    if ($TeamArenaKey -and (Test-Path -LiteralPath $teamDirectory -PathType Container)) {
        $targets.Add([pscustomobject]@{ Game = 'Team Arena'; Path = (Join-Path $teamDirectory 'q3key'); Key = $TeamArenaKey })
    }
    $targets.ToArray()
}

function Install-KeysToRoot([string]$GameRoot,[string]$ArenaKey,[string]$TeamArenaKey) {
    $targets = @(Get-KeyInstallTargets $GameRoot $ArenaKey $TeamArenaKey)
    if ($targets.Count -eq 0) { throw 'No existing target matches the generated keys.' }
    foreach ($target in $targets) { Write-KeyFile $target.Path $target.Key }
    $targets
}

function Get-PropertyValue($Object,[string]$Name) {
    if ($null -eq $Object) { return $null }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) { return $null }
    $property.Value
}

function Find-GameInstallations {
    $found = @{}
    $addInstallation = {
        param([string]$Source,[string]$Root)
        if (-not $Root -or -not (Test-Path -LiteralPath $Root -PathType Container)) { return }
        try { $normalized = [System.IO.Path]::GetFullPath($Root).TrimEnd('\') } catch { return }
        $hasArena = Test-Path -LiteralPath (Join-Path $normalized 'baseq3') -PathType Container
        $hasTeam = Test-Path -LiteralPath (Join-Path $normalized 'missionpack') -PathType Container
        if (-not $hasArena -and -not $hasTeam) { return }
        $key = $normalized.ToLowerInvariant()
        if ($found.ContainsKey($key)) { return }
        $games = @()
        if ($hasArena) { $games += 'Arena' }
        if ($hasTeam) { $games += 'Team Arena' }
        $found[$key] = [pscustomobject]@{
            Source = $Source; Root = $normalized; HasArena = $hasArena; HasTeamArena = $hasTeam
            Display = '[{0}] {1}  //  {2}' -f $Source,$normalized,($games -join ' + ')
        }
    }

    $steamRoots = New-Object 'System.Collections.Generic.List[string]'
    foreach ($registryPath in @('HKCU:\SOFTWARE\Valve\Steam','HKLM:\SOFTWARE\WOW6432Node\Valve\Steam','HKLM:\SOFTWARE\Valve\Steam')) {
        $steamData = Get-ItemProperty -Path $registryPath -ErrorAction SilentlyContinue
        foreach ($propertyName in @('SteamPath','InstallPath')) {
            $value = Get-PropertyValue $steamData $propertyName
            if ($value -and -not $steamRoots.Contains($value)) { $steamRoots.Add($value) }
        }
    }
    foreach ($steamRoot in @($steamRoots)) {
        $libraries = New-Object 'System.Collections.Generic.List[string]'
        $libraries.Add($steamRoot)
        $libraryFile = Join-Path $steamRoot 'steamapps\libraryfolders.vdf'
        if (Test-Path -LiteralPath $libraryFile) {
            $libraryText = Get-Content -Raw -LiteralPath $libraryFile
            foreach ($match in [regex]::Matches($libraryText,'"path"\s+"([^"]+)"')) {
                $library = $match.Groups[1].Value.Replace('\\','\')
                if (-not $libraries.Contains($library)) { $libraries.Add($library) }
            }
        }
        foreach ($library in @($libraries)) {
            foreach ($appId in @('2200','2350')) {
                $manifest = Join-Path $library ('steamapps\appmanifest_{0}.acf' -f $appId)
                if (-not (Test-Path -LiteralPath $manifest)) { continue }
                $manifestText = Get-Content -Raw -LiteralPath $manifest
                if ($manifestText -match '"installdir"\s+"([^"]+)"') {
                    & $addInstallation 'Steam' (Join-Path $library ('steamapps\common\{0}' -f $matches[1]))
                }
            }
        }
    }

    foreach ($registryPattern in @('HKLM:\SOFTWARE\GOG.com\Games\*','HKLM:\SOFTWARE\WOW6432Node\GOG.com\Games\*','HKCU:\SOFTWARE\GOG.com\Games\*')) {
        foreach ($game in @(Get-ItemProperty -Path $registryPattern -ErrorAction SilentlyContinue)) {
            $gameName = Get-PropertyValue $game 'gameName'
            $gameTitle = Get-PropertyValue $game 'title'
            if (($gameName -match 'Quake\s*III') -or ($gameTitle -match 'Quake\s*III')) {
                & $addInstallation 'GOG' (Get-PropertyValue $game 'path')
            }
        }
    }

    $uninstallPatterns = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    foreach ($entry in @(Get-ItemProperty -Path $uninstallPatterns -ErrorAction SilentlyContinue)) {
        $displayName = Get-PropertyValue $entry 'DisplayName'
        if ($displayName -notmatch 'Quake\s*III') { continue }
        $uninstallString = Get-PropertyValue $entry 'UninstallString'
        $publisher = Get-PropertyValue $entry 'Publisher'
        $psPath = Get-PropertyValue $entry 'PSPath'
        $source = if ($uninstallString -match 'steam') { 'Steam' } elseif (($psPath -match 'GOG') -or ($publisher -match 'GOG')) { 'GOG' } else { 'Original / CD-ROM' }
        & $addInstallation $source (Get-PropertyValue $entry 'InstallLocation')
    }

    foreach ($registryPath in @('HKLM:\SOFTWARE\id\Quake III Arena','HKLM:\SOFTWARE\WOW6432Node\id\Quake III Arena','HKCU:\SOFTWARE\id\Quake III Arena')) {
        $data = Get-ItemProperty -Path $registryPath -ErrorAction SilentlyContinue
        & $addInstallation 'Original / CD-ROM' (Get-PropertyValue $data 'InstallPath')
    }

    $programFiles = [Environment]::GetFolderPath('ProgramFiles')
    $programFilesX86 = [Environment]::GetFolderPath('ProgramFilesX86')
    foreach ($basePath in @($programFilesX86,$programFiles)) {
        if (-not $basePath) { continue }
        & $addInstallation 'Original / CD-ROM' (Join-Path $basePath 'Quake III Arena')
        & $addInstallation 'GOG' (Join-Path $basePath 'GOG Galaxy\Games\Quake III Arena')
        & $addInstallation 'GOG' (Join-Path $basePath 'GOG Galaxy\Games\Quake III Gold')
        & $addInstallation 'ioquake3' (Join-Path $basePath 'ioquake3')
    }
    foreach ($fallback in @('C:\Quake III Arena','C:\Quake3','C:\ioquake3','C:\GOG Games\Quake III Arena','C:\GOG Games\Quake III Gold')) {
        $source = if ($fallback -match 'GOG') { 'GOG' } elseif ($fallback -match 'ioquake') { 'ioquake3' } else { 'Original / CD-ROM' }
        & $addInstallation $source $fallback
    }

    $appData = [Environment]::GetFolderPath('ApplicationData')
    if ($appData) { & $addInstallation 'ioquake3 user data' (Join-Path $appData 'Quake3') }
    $repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
    & $addInstallation 'Local / portable' $repositoryRoot
    & $addInstallation 'Local / portable' (Split-Path $repositoryRoot -Parent)
    @($found.Values | Sort-Object Source,Root)
}

if ($SelfTest) {
    1..100 | ForEach-Object {
        $arena = New-ArenaKey
        if ($arena -notmatch '^[237abcdghjlprstw]{16}$') { throw ('Arena self-test failed: {0}' -f $arena) }
        $team = New-TeamArenaKey
        if ($team -notmatch '^[237ABCDGHJLPRSTW]{4}(-[237ABCDGHJLPRSTW]{4}){3}-[0-9A-F]{2}$') { throw ('Team Arena self-test failed: {0}' -f $team) }
        $raw = Get-RawTeamArenaKey $team
        $expectedSuffix = '-{0}' -f (Get-TeamArenaChecksum $raw)
        if (-not $team.EndsWith($expectedSuffix)) { throw ('Checksum self-test failed: {0}' -f $team) }
    }
    $testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('q3-keygen-selftest-{0}' -f [guid]::NewGuid().ToString('N'))
    $testArenaDirectory = Join-Path $testRoot 'baseq3'
    $testTeamDirectory = Join-Path $testRoot 'missionpack'
    try {
        New-Item -ItemType Directory -Path $testArenaDirectory,$testTeamDirectory | Out-Null
        $testArenaKey = New-ArenaKey
        $testTeamDisplay = New-TeamArenaKey
        $testTeamKey = Get-RawTeamArenaKey $testTeamDisplay
        $installedTargets = @(Install-KeysToRoot $testRoot $testArenaKey $testTeamKey)
        if ($installedTargets.Count -ne 2) { throw 'Direct-install self-test did not return two targets.' }
        if ((Get-Content -Raw (Join-Path $testArenaDirectory 'q3key')) -ne $testArenaKey) {
            throw 'Direct-install self-test failed for Arena.'
        }
        if ((Get-Content -Raw (Join-Path $testTeamDirectory 'q3key')) -ne $testTeamKey) {
            throw 'Direct-install self-test failed for Team Arena.'
        }
    } finally {
        Remove-Item -LiteralPath (Join-Path $testArenaDirectory 'q3key') -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath (Join-Path $testTeamDirectory 'q3key') -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $testArenaDirectory -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $testTeamDirectory -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $testRoot -Force -ErrorAction SilentlyContinue
    }
    $detected = @(Find-GameInstallations)
    foreach ($installation in $detected) {
        if (-not $installation.Root -or -not $installation.Display) { throw 'Installation-detection self-test returned an incomplete result.' }
    }
    Write-Output ('PASS: 100 valid key pairs, direct installation, and detection verified ({0} installation(s) found).' -f $detected.Count)
    exit 0
}

if ($DetectOnly) {
    Find-GameInstallations | Format-Table Source,HasArena,HasTeamArena,Root -AutoSize
    exit 0
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

# Quake III-inspired late-1990s palette: pale circuitry, black steel, menu red and hot orange.
$void = [System.Drawing.Color]::FromArgb(204,205,199)
$iron = [System.Drawing.Color]::FromArgb(22,20,18)
$ironDark = [System.Drawing.Color]::FromArgb(8,8,7)
$blood = [System.Drawing.Color]::FromArgb(132,0,0)
$bloodHot = [System.Drawing.Color]::FromArgb(220,18,8)
$rust = [System.Drawing.Color]::FromArgb(240,126,14)
$bone = [System.Drawing.Color]::FromArgb(232,225,205)
$ash = [System.Drawing.Color]::FromArgb(160,157,147)
$acid = [System.Drawing.Color]::FromArgb(255,178,35)
$black = [System.Drawing.Color]::FromArgb(2,2,2)
$circuit = [System.Drawing.Color]::FromArgb(132,137,132)
$circuitLight = [System.Drawing.Color]::FromArgb(230,231,226)

function New-UiFont([float]$Size, [System.Drawing.FontStyle]$Style = [System.Drawing.FontStyle]::Regular) {
    New-Object System.Drawing.Font('Arial Narrow',$Size,$Style)
}

function New-TitleFont([float]$Size) {
    New-Object System.Drawing.Font('Impact',$Size,[System.Drawing.FontStyle]::Regular)
}

function New-RetroButton([string]$Text,[int]$X,[int]$Y,[int]$Width,[int]$Height,[System.Drawing.Color]$Accent = $rust) {
    $button = New-Object System.Windows.Forms.Button
    $button.Text = $Text
    $button.Size = New-Object System.Drawing.Size($Width,$Height)
    $button.Location = New-Object System.Drawing.Point($X,$Y)
    $button.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $button.FlatAppearance.BorderColor = $Accent
    $button.FlatAppearance.BorderSize = 2
    $button.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(69,8,3)
    $button.FlatAppearance.MouseDownBackColor = $blood
    $button.BackColor = $black
    $button.ForeColor = $Accent
    $button.Font = New-UiFont 9 ([System.Drawing.FontStyle]::Bold)
    $button.Cursor = [System.Windows.Forms.Cursors]::Hand
    $button.TabStop = $false
    $button.Add_MouseEnter({ $this.ForeColor = $bone })
    $button.Add_MouseLeave({ $this.ForeColor = $this.FlatAppearance.BorderColor })
    $button
}

function Select-KeySavePath([string]$Title,[string]$SuggestedDirectory) {
    $repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
    $existingDirectories = @(Find-GameInstallations | ForEach-Object {
        $candidate = Join-Path $_.Root $SuggestedDirectory
        if (Test-Path -LiteralPath $candidate -PathType Container) { $candidate }
    })
    $initialDirectory = if ($existingDirectories.Count -gt 0) { $existingDirectories[0] } else { $repositoryRoot }

    $dialog = New-Object System.Windows.Forms.SaveFileDialog
    $dialog.Title = $Title
    $dialog.Filter = 'Generated Quake III data (q3key)|q3key|All files (*.*)|*.*'
    $dialog.FileName = 'q3key'
    $dialog.InitialDirectory = $initialDirectory
    $dialog.AddExtension = $false
    $dialog.OverwritePrompt = $true
    try {
        if ($dialog.ShowDialog($form) -eq [System.Windows.Forms.DialogResult]::OK) {
            return $dialog.FileName
        }
    } finally {
        $dialog.Dispose()
    }
    $null
}

function New-SectionPanel([string]$Heading,[string]$PathText,[int]$Y,[System.Drawing.Color]$Accent) {
    $panel = New-Object System.Windows.Forms.Panel
    $panel.Location = New-Object System.Drawing.Point(24,$Y)
    $panel.Size = New-Object System.Drawing.Size(672,108)
    $panel.BackColor = $iron
    $panel.Tag = $Accent
    $panel.Add_Paint({
        param($sender,$eventArgs)
        $graphics = $eventArgs.Graphics
        $outerPen = New-Object System.Drawing.Pen($black,3)
        $innerPen = New-Object System.Drawing.Pen(([System.Drawing.Color]$sender.Tag),1)
        $rivetBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(93,82,66))
        try {
            $graphics.DrawRectangle($outerPen,1,1,$sender.Width-3,$sender.Height-3)
            $graphics.DrawRectangle($innerPen,5,5,$sender.Width-11,$sender.Height-11)
            foreach ($point in @(
                @(10,10),
                @(($sender.Width - 15),10),
                @(10,($sender.Height - 15)),
                @(($sender.Width - 15),($sender.Height - 15))
            )) {
                $graphics.FillEllipse($rivetBrush,$point[0],$point[1],5,5)
            }
        } finally { $outerPen.Dispose(); $innerPen.Dispose(); $rivetBrush.Dispose() }
    })
    $headingLabel = New-Object System.Windows.Forms.Label
    $headingLabel.Text = $Heading
    $headingLabel.Font = New-UiFont 13 ([System.Drawing.FontStyle]::Bold)
    $headingLabel.ForeColor = $Accent
    $headingLabel.BackColor = [System.Drawing.Color]::Transparent
    $headingLabel.AutoSize = $true
    $headingLabel.Location = New-Object System.Drawing.Point(20,14)
    $panel.Controls.Add($headingLabel)
    $pathLabel = New-Object System.Windows.Forms.Label
    $pathLabel.Text = $PathText
    $pathLabel.Font = New-UiFont 8
    $pathLabel.ForeColor = $ash
    $pathLabel.BackColor = [System.Drawing.Color]::Transparent
    $pathLabel.AutoSize = $true
    $pathLabel.Location = New-Object System.Drawing.Point(23,37)
    $panel.Controls.Add($pathLabel)
    $panel
}

function Show-AboutDialog {
    $about = New-Object System.Windows.Forms.Form
    $about.Text = 'About Q3 Arena + Team Arena Keygen'
    $about.ClientSize = New-Object System.Drawing.Size(620,500)
    $about.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterParent
    $about.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
    $about.MaximizeBox = $false
    $about.MinimizeBox = $false
    $about.ShowInTaskbar = $false
    $about.BackColor = $black
    $about.ForeColor = $bone
    $about.Font = New-UiFont 9

    $aboutTitle = New-Object System.Windows.Forms.Label
    $aboutTitle.Text = 'Q3 ARENA + TEAM ARENA KEYGEN  v{0}' -f $appVersion
    $aboutTitle.Font = New-UiFont 18 ([System.Drawing.FontStyle]::Bold)
    $aboutTitle.ForeColor = $rust
    $aboutTitle.AutoSize = $true
    $aboutTitle.Location = New-Object System.Drawing.Point(24,20)
    $about.Controls.Add($aboutTitle)

    $aboutSubtitle = New-Object System.Windows.Forms.Label
    $aboutSubtitle.Text = 'OFFLINE // OPEN SOURCE // INDEPENDENT FAN PROJECT'
    $aboutSubtitle.Font = New-UiFont 9 ([System.Drawing.FontStyle]::Bold)
    $aboutSubtitle.ForeColor = $bloodHot
    $aboutSubtitle.AutoSize = $true
    $aboutSubtitle.Location = New-Object System.Drawing.Point(27,53)
    $about.Controls.Add($aboutSubtitle)

    $aboutText = New-Object System.Windows.Forms.RichTextBox
    $aboutText.Location = New-Object System.Drawing.Point(24,82)
    $aboutText.Size = New-Object System.Drawing.Size(572,360)
    $aboutText.ReadOnly = $true
    $aboutText.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
    $aboutText.BackColor = $iron
    $aboutText.ForeColor = $bone
    $aboutText.Font = New-UiFont 10
    $aboutText.DetectUrls = $true
    $aboutText.Text = @'
PURPOSE
Offline keygen and interoperability proof of concept based on local validation routines published in id Software's Quake III Arena GPL source release. It includes no official logo, game asset, executable, commercial key database, telemetry or remote service.

REQUIREMENTS AND PERMITTED USE
The keygen runs with Windows PowerShell and Windows Forms; game data is not required to generate values. Intended use requires a lawfully acquired physical or digital copy of Quake III Arena, plus Team Arena ownership for mission-pack use. Generated keys are for personal use only on community-operated servers whose rules permit them.

INSTALLATION SUPPORT
Detects Steam libraries, GOG registry/install records, original CD-ROM locations and ioquake3 user/portable locations. Direct installation writes only to existing baseq3 or missionpack directories and asks before replacement. SAVE AS... remains available for any manual destination.

OPEN-SOURCE CONTEXT
id Software source: https://github.com/id-Software/Quake-III-Arena
ioquake3: https://ioquake3.org/ and https://github.com/ioquake/ioq3
ioquake3 is a newer community engine and is not a dependency of this keygen.

LEGAL
Independent fan-made project; not affiliated with or endorsed by id Software, Bethesda, ZeniMax, ioquake3, Valve, GOG or any server operator. Quake and related marks belong to their respective owners. Repository code is GPL-2.0-only. No warranty. See README.md and LEGAL.md for the complete notice.
'@
    $about.Controls.Add($aboutText)

    $closeAbout = New-RetroButton 'CLOSE' 470 454 126 30 $rust
    $closeAbout.Add_Click({ $this.FindForm().Close() })
    $about.Controls.Add($closeAbout)
    [void]$about.ShowDialog($form)
    $about.Dispose()
}

$form = New-Object System.Windows.Forms.Form
$form.Text = 'SpiRaL'' // Q3 ARENA + TEAM ARENA KEYGEN v{0}' -f $appVersion
$form.ClientSize = New-Object System.Drawing.Size(720,650)
$form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedSingle
$form.MaximizeBox = $false
$form.BackColor = $void
$form.ForeColor = $bone
$form.Font = New-UiFont 9
$form.KeyPreview = $true
$form.Add_Paint({
    param($sender,$eventArgs)
    $graphics = $eventArgs.Graphics
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $backgroundBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
        (New-Object System.Drawing.Rectangle(0,0,$sender.ClientSize.Width,$sender.ClientSize.Height)),
        $circuitLight,$void,90)
    $tracePen = New-Object System.Drawing.Pen($circuit,1)
    $highlightPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(240,241,237),1)
    $padBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(118,123,119))
    $edgePen = New-Object System.Drawing.Pen($black,3)
    $redPen = New-Object System.Drawing.Pen($blood,2)
    $bloodBrush = New-Object System.Drawing.SolidBrush($blood)
    $hotBloodBrush = New-Object System.Drawing.SolidBrush($bloodHot)
    try {
        $graphics.FillRectangle($backgroundBrush,0,0,$sender.ClientSize.Width,$sender.ClientSize.Height)
        $graphics.DrawRectangle($edgePen,7,7,$sender.ClientSize.Width-15,$sender.ClientSize.Height-15)
        $graphics.DrawRectangle($redPen,11,11,$sender.ClientSize.Width-23,$sender.ClientSize.Height-23)
        foreach ($trace in @(
            @(0,62,90,62,118,34,205,34), @(0,86,70,86,103,119,180,119),
            @(720,54,640,54,607,87,528,87), @(720,110,655,110,621,76,570,76),
            @(0,288,38,288,76,250,132,250), @(720,300,675,300,646,271,590,271),
            @(0,518,72,518,104,550,171,550), @(720,532,652,532,620,564,548,564),
            @(92,650,92,610,128,574,210,574), @(614,650,614,612,580,578,520,578))) {
            for ($i = 0; $i -lt $trace.Count - 2; $i += 2) {
                $graphics.DrawLine($tracePen,$trace[$i],$trace[$i+1],$trace[$i+2],$trace[$i+3])
                $graphics.DrawLine($highlightPen,$trace[$i],$trace[$i+1]+2,$trace[$i+2],$trace[$i+3]+2)
            }
            for ($i = 0; $i -lt $trace.Count; $i += 2) { $graphics.FillEllipse($padBrush,$trace[$i]-3,$trace[$i+1]-3,7,7) }
        }
        foreach ($pad in @(@(32,34),@(56,34),@(664,32),@(688,32),@(32,612),@(56,612),@(664,612),@(688,612))) {
            $graphics.DrawEllipse($tracePen,$pad[0]-5,$pad[1]-5,10,10)
            $graphics.FillEllipse($padBrush,$pad[0]-2,$pad[1]-2,4,4)
        }
        $graphics.FillRectangle($bloodBrush,222,91,276,2)
        foreach ($drip in @(@(253,91,4,10),@(307,91,6,6),@(359,91,4,13),@(421,91,7,8),@(475,91,3,11))) {
            $graphics.FillPolygon($bloodBrush,[System.Drawing.Point[]]@(
                (New-Object System.Drawing.Point($drip[0],$drip[1])),
                (New-Object System.Drawing.Point(($drip[0]+$drip[2]),$drip[1])),
                (New-Object System.Drawing.Point(($drip[0]+[int]($drip[2]/2)),($drip[1]+$drip[3])))))
            $graphics.FillEllipse($hotBloodBrush,$drip[0],$drip[1]-1,$drip[2],3)
        }
        foreach ($drop in @(@(278,101,3),@(386,99,4),@(450,103,3))) {
            $graphics.FillEllipse($bloodBrush,$drop[0],$drop[1],$drop[2],$drop[2]+2)
        }
    } finally {
        $backgroundBrush.Dispose(); $tracePen.Dispose(); $highlightPen.Dispose()
        $padBrush.Dispose(); $edgePen.Dispose(); $redPen.Dispose()
        $bloodBrush.Dispose(); $hotBloodBrush.Dispose()
    }
})

$titleShadow = New-Object System.Windows.Forms.Label
$titleShadow.Text = 'QUAKE III KEYGEN'
$titleShadow.Font = New-TitleFont 29
$titleShadow.ForeColor = $black
$titleShadow.BackColor = [System.Drawing.Color]::Transparent
$titleShadow.AutoSize = $true
$titleShadow.Location = New-Object System.Drawing.Point(213,21)
$form.Controls.Add($titleShadow)

$title = New-Object System.Windows.Forms.Label
$title.Text = 'QUAKE III KEYGEN'
$title.Font = New-TitleFont 29
$title.ForeColor = $rust
$title.BackColor = [System.Drawing.Color]::Transparent
$title.AutoSize = $true
$title.Location = New-Object System.Drawing.Point(210,18)
$form.Controls.Add($title)
$title.BringToFront()

$subtitle = New-Object System.Windows.Forms.Label
$subtitle.Text = 'A R E N A   +   T E A M   A R E N A'
$subtitle.Font = New-UiFont 10 ([System.Drawing.FontStyle]::Bold)
$subtitle.ForeColor = $bloodHot
$subtitle.BackColor = [System.Drawing.Color]::Transparent
$subtitle.AutoSize = $true
$subtitle.Location = New-Object System.Drawing.Point(230,70)
$form.Controls.Add($subtitle)

$arenaPanel = New-SectionPanel 'II. QUAKE III ARENA' 'GENERATE, SAVE ANYWHERE, OR INSTALL TO THE SELECTED TARGET' 224 $rust
$form.Controls.Add($arenaPanel)
$arenaBox = New-Object System.Windows.Forms.TextBox
$arenaBox.Font = New-UiFont 16 ([System.Drawing.FontStyle]::Bold)
$arenaBox.Size = New-Object System.Drawing.Size(324,32)
$arenaBox.Location = New-Object System.Drawing.Point(22,61)
$arenaBox.TextAlign = [System.Windows.Forms.HorizontalAlignment]::Center
$arenaBox.ReadOnly = $true
$arenaBox.BackColor = $black
$arenaBox.ForeColor = $bone
$arenaBox.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$arenaPanel.Controls.Add($arenaBox)
$btnArena = New-RetroButton 'GENERATE' 356 60 92 34 $rust
$arenaPanel.Controls.Add($btnArena)
$btnSaveArena = New-RetroButton 'SAVE AS...' 458 60 96 34 $bloodHot
$arenaPanel.Controls.Add($btnSaveArena)
$btnInstallArena = New-RetroButton 'INSTALL' 564 60 86 34 $rust
$arenaPanel.Controls.Add($btnInstallArena)

$teamPanel = New-SectionPanel 'III. QUAKE III TEAM ARENA' 'GENERATE, SAVE ANYWHERE, OR INSTALL TO THE SELECTED TARGET' 342 $bloodHot
$form.Controls.Add($teamPanel)
$teamBox = New-Object System.Windows.Forms.TextBox
$teamBox.Font = New-UiFont 16 ([System.Drawing.FontStyle]::Bold)
$teamBox.Size = New-Object System.Drawing.Size(324,32)
$teamBox.Location = New-Object System.Drawing.Point(22,61)
$teamBox.TextAlign = [System.Windows.Forms.HorizontalAlignment]::Center
$teamBox.ReadOnly = $true
$teamBox.BackColor = $black
$teamBox.ForeColor = $bloodHot
$teamBox.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$teamPanel.Controls.Add($teamBox)
$btnTeam = New-RetroButton 'GENERATE' 356 60 92 34 $rust
$teamPanel.Controls.Add($btnTeam)
$btnSaveTeam = New-RetroButton 'SAVE AS...' 458 60 96 34 $bloodHot
$teamPanel.Controls.Add($btnSaveTeam)
$btnInstallTeam = New-RetroButton 'INSTALL' 564 60 86 34 $rust
$teamPanel.Controls.Add($btnInstallTeam)

$btnBoth = New-RetroButton 'GENERATE BOTH' 24 470 214 44 $rust
$btnBoth.Font = New-UiFont 12 ([System.Drawing.FontStyle]::Bold)
$form.Controls.Add($btnBoth)
$btnSaveBoth = New-RetroButton 'SAVE BOTH AS...' 253 470 214 44 $bloodHot
$btnSaveBoth.Font = New-UiFont 12 ([System.Drawing.FontStyle]::Bold)
$form.Controls.Add($btnSaveBoth)
$btnInstallBoth = New-RetroButton 'INSTALL BOTH' 482 470 214 44 $rust
$btnInstallBoth.Font = New-UiFont 12 ([System.Drawing.FontStyle]::Bold)
$form.Controls.Add($btnInstallBoth)

$installPanel = New-Object System.Windows.Forms.Panel
$installPanel.Location = New-Object System.Drawing.Point(24,106)
$installPanel.Size = New-Object System.Drawing.Size(672,112)
$installPanel.BackColor = $iron
$installPanel.Add_Paint({
    param($sender,$eventArgs)
    $outerPen = New-Object System.Drawing.Pen($black,3)
    $innerPen = New-Object System.Drawing.Pen($blood,1)
    try {
        $eventArgs.Graphics.DrawRectangle($outerPen,1,1,$sender.Width-3,$sender.Height-3)
        $eventArgs.Graphics.DrawRectangle($innerPen,5,5,$sender.Width-11,$sender.Height-11)
    } finally { $outerPen.Dispose(); $innerPen.Dispose() }
})
$form.Controls.Add($installPanel)

$installLabel = New-Object System.Windows.Forms.Label
$installLabel.Text = 'I. DETECTED INSTALLATION / SAVE TARGET'
$installLabel.Font = New-UiFont 13 ([System.Drawing.FontStyle]::Bold)
$installLabel.ForeColor = $bloodHot
$installLabel.AutoSize = $true
$installLabel.Location = New-Object System.Drawing.Point(20,14)
$installPanel.Controls.Add($installLabel)

$installHint = New-Object System.Windows.Forms.Label
$installHint.Text = 'THIS SELECTION DIRECTS ARENA, TEAM ARENA AND INSTALL BOTH'
$installHint.Font = New-UiFont 8
$installHint.ForeColor = $ash
$installHint.AutoSize = $true
$installHint.Location = New-Object System.Drawing.Point(23,39)
$installPanel.Controls.Add($installHint)

$installationCombo = New-Object System.Windows.Forms.ComboBox
$installationCombo.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$installationCombo.Location = New-Object System.Drawing.Point(22,65)
$installationCombo.Size = New-Object System.Drawing.Size(514,25)
$installationCombo.DropDownWidth = 640
$installationCombo.BackColor = $black
$installationCombo.ForeColor = $bone
$installationCombo.Font = New-UiFont 9 ([System.Drawing.FontStyle]::Bold)
$installPanel.Controls.Add($installationCombo)

$btnRescan = New-RetroButton 'RESCAN' 546 63 104 30 $rust
$installPanel.Controls.Add($btnRescan)

function Refresh-InstallationList {
    $installationCombo.Items.Clear()
    $script:detectedInstallations = @(Find-GameInstallations)
    if ($script:detectedInstallations.Count -eq 0) {
        [void]$installationCombo.Items.Add('[NONE] No supported installation detected - use SAVE AS...')
        $btnInstallArena.Enabled = $false
        $btnInstallTeam.Enabled = $false
        $btnInstallBoth.Enabled = $false
        $status.ForeColor = $bloodHot
        $status.Text = '> NO INSTALLATION DETECTED. MANUAL SAVE AS... IS AVAILABLE.'
    } else {
        foreach ($installation in $script:detectedInstallations) { [void]$installationCombo.Items.Add([string]$installation.Display) }
        $status.ForeColor = $acid
        $status.Text = '> {0} INSTALLATION(S) DETECTED. GENERATE KEYS.' -f $script:detectedInstallations.Count
    }
    $installationCombo.SelectedIndex = 0
    Update-InstallButtons
}

function Update-InstallButtons {
    $selectedIndex = $installationCombo.SelectedIndex
    $valid = $selectedIndex -ge 0 -and $selectedIndex -lt $script:detectedInstallations.Count
    if (-not $valid) {
        $btnInstallArena.Enabled = $false
        $btnInstallTeam.Enabled = $false
        $btnInstallBoth.Enabled = $false
        return
    }
    $selected = $script:detectedInstallations[$selectedIndex]
    $btnInstallArena.Enabled = [bool]$selected.HasArena
    $btnInstallTeam.Enabled = [bool]$selected.HasTeamArena
    $btnInstallBoth.Enabled = [bool]($selected.HasArena -and $selected.HasTeamArena)
}
$installationCombo.Add_SelectedIndexChanged({ Update-InstallButtons })

$pathToolTip = New-Object System.Windows.Forms.ToolTip
$pathToolTip.AutoPopDelay = 20000
$pathToolTip.InitialDelay = 350
$pathToolTip.ReshowDelay = 100
$arenaSaveHint = @(
    'Arena q3key examples:',
    'CD-ROM: C:\Program Files (x86)\Quake III Arena\baseq3\q3key',
    'Steam: C:\Program Files (x86)\Steam\steamapps\common\Quake 3 Arena\baseq3\q3key',
    'GOG: <GOG game folder>\baseq3\q3key',
    'ioquake3: %APPDATA%\Quake3\baseq3\q3key'
) -join [Environment]::NewLine
$teamSaveHint = $arenaSaveHint.Replace('Arena q3key','Team Arena q3key').Replace('\baseq3\','\missionpack\')
$pathToolTip.SetToolTip($btnSaveArena,$arenaSaveHint)
$pathToolTip.SetToolTip($btnSaveTeam,$teamSaveHint)
$pathToolTip.SetToolTip($btnInstallArena,'Install the Arena key into the existing baseq3 folder of the selected detected installation.')
$pathToolTip.SetToolTip($btnInstallTeam,'Install the Team Arena key into the existing missionpack folder of the selected detected installation.')
$pathToolTip.SetToolTip($btnInstallBoth,'Install both generated keys into the existing baseq3 and missionpack folders of the selected detected installation.')
$pathToolTip.SetToolTip($btnSaveBoth,'Choose two manual Save As destinations. Both are selected before either value is written.')
$pathToolTip.SetToolTip($installationCombo,'Detected from Steam libraries, GOG or Windows registry data, original CD-ROM defaults, and ioquake3 locations.')

$statusPanel = New-Object System.Windows.Forms.Panel
$statusPanel.Location = New-Object System.Drawing.Point(24,530)
$statusPanel.Size = New-Object System.Drawing.Size(672,48)
$statusPanel.BackColor = $black
$form.Controls.Add($statusPanel)
$status = New-Object System.Windows.Forms.Label
$status.Text = '> SYSTEM READY. SCANNING INSTALLATIONS...'
$status.Font = New-UiFont 9 ([System.Drawing.FontStyle]::Bold)
$status.ForeColor = $acid
$status.AutoSize = $true
$status.Location = New-Object System.Drawing.Point(12,15)
$statusPanel.Controls.Add($status)

$btnAbout = New-RetroButton 'ABOUT' 602 594 94 26 $rust
$form.Controls.Add($btnAbout)

$footer = New-Object System.Windows.Forms.Label
$footer.Text = 'v{0} // GPL-2.0-ONLY // OFFLINE KEYGEN // PERMITTED COMMUNITY SERVERS // ESC TO EXIT' -f $appVersion
$footer.Font = New-UiFont 7
$footer.ForeColor = $ash
$footer.BackColor = [System.Drawing.Color]::Transparent
$footer.AutoSize = $true
$footer.Location = New-Object System.Drawing.Point(24,608)
$form.Controls.Add($footer)

$btnArena.Add_Click({
    $arenaBox.Text = New-ArenaKey
    [System.Windows.Forms.Clipboard]::SetText($arenaBox.Text)
    $status.ForeColor = $rust
    $status.Text = '> ARENA KEY GENERATED + COPIED TO CLIPBOARD.'
})
$btnTeam.Add_Click({
    $teamBox.Text = New-TeamArenaKey
    [System.Windows.Forms.Clipboard]::SetText($teamBox.Text)
    $status.ForeColor = $bloodHot
    $status.Text = '> TEAM ARENA KEY GENERATED + COPIED TO CLIPBOARD.'
})
$btnAbout.Add_Click({ Show-AboutDialog })
$btnBoth.Add_Click({
    $arenaBox.Text = New-ArenaKey
    $teamBox.Text = New-TeamArenaKey
    $clipboardText = '{0}{1}{2}' -f $arenaBox.Text,[Environment]::NewLine,$teamBox.Text
    [System.Windows.Forms.Clipboard]::SetText($clipboardText)
    $status.ForeColor = $acid
    $status.Text = '> BOTH KEYS GENERATED + COPIED TO CLIPBOARD.'
})
$btnSaveArena.Add_Click({
    if (-not $arenaBox.Text) {
        $status.ForeColor = $bloodHot
        $status.Text = '> ERROR: GENERATE AN ARENA KEY FIRST.'
        return
    }
    $savePath = Select-KeySavePath 'Save Quake III Arena key' 'baseq3'
    if (-not $savePath) { $status.Text = '> SAVE CANCELLED.'; return }
    Write-KeyFile $savePath $arenaBox.Text
    $status.ForeColor = $rust
    $status.Text = '> ARENA KEY SAVED.'
})
$btnSaveTeam.Add_Click({
    if (-not $teamBox.Text) {
        $status.ForeColor = $bloodHot
        $status.Text = '> ERROR: GENERATE A TEAM ARENA KEY FIRST.'
        return
    }
    $savePath = Select-KeySavePath 'Save Quake III Team Arena key' 'missionpack'
    if (-not $savePath) { $status.Text = '> SAVE CANCELLED.'; return }
    Write-KeyFile $savePath (Get-RawTeamArenaKey $teamBox.Text)
    $status.ForeColor = $bloodHot
    $status.Text = '> TEAM ARENA KEY SAVED.'
})
$btnSaveBoth.Add_Click({
    if (-not $arenaBox.Text -or -not $teamBox.Text) {
        $status.ForeColor = $bloodHot
        $status.Text = '> ERROR: GENERATE BOTH KEYS FIRST.'
        return
    }
    $arenaSavePath = Select-KeySavePath 'Save Quake III Arena key (1 of 2)' 'baseq3'
    if (-not $arenaSavePath) { $status.Text = '> SAVE BOTH CANCELLED. NOTHING WRITTEN.'; return }
    $teamSavePath = Select-KeySavePath 'Save Team Arena key (2 of 2)' 'missionpack'
    if (-not $teamSavePath) { $status.Text = '> SAVE BOTH CANCELLED. NOTHING WRITTEN.'; return }
    if ([System.IO.Path]::GetFullPath($arenaSavePath).Equals(
        [System.IO.Path]::GetFullPath($teamSavePath),[System.StringComparison]::OrdinalIgnoreCase)) {
        $status.ForeColor = $bloodHot
        $status.Text = '> ERROR: CHOOSE TWO DIFFERENT SAVE DESTINATIONS.'
        [System.Windows.Forms.MessageBox]::Show(
            $form,'Arena and Team Arena contain different values and cannot be saved to the same path. Nothing was written.',
            'Choose two destinations',[System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        ) | Out-Null
        return
    }
    Write-KeyFile $arenaSavePath $arenaBox.Text
    Write-KeyFile $teamSavePath (Get-RawTeamArenaKey $teamBox.Text)
    $status.ForeColor = $acid
    $status.Text = '> BOTH KEYS SAVED TO THE TWO SELECTED DESTINATIONS.'
})

$installSelectedKeys = {
    param([string]$ArenaKey,[string]$TeamKey,[int]$ExpectedCount,[string]$Label)
    $selectedIndex = $installationCombo.SelectedIndex
    if ($selectedIndex -lt 0 -or $selectedIndex -ge $script:detectedInstallations.Count) {
        $status.ForeColor = $bloodHot
        $status.Text = '> ERROR: NO DETECTED INSTALLATION SELECTED.'
        return
    }
    $installation = $script:detectedInstallations[$selectedIndex]
    $targets = @(Get-KeyInstallTargets $installation.Root $ArenaKey $TeamKey)
    if ($targets.Count -ne $ExpectedCount) {
        $status.ForeColor = $bloodHot
        $status.Text = '> ERROR: SELECTED INSTALLATION DOES NOT HAVE THE REQUIRED TARGET(S).'
        [System.Windows.Forms.MessageBox]::Show(
            $form,
            ('The selected installation does not have every existing folder required for {0}. No folder was created and nothing was written.' -f $Label),
            'No compatible target',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        ) | Out-Null
        return
    }
    $targetLines = @($targets | ForEach-Object { '{0}: {1}' -f $_.Game,$_.Path })
    $existingTargets = @($targets | Where-Object { Test-Path -LiteralPath $_.Path })
    $prompt = @(
        ('Install {0} into this detected installation?' -f $Label),
        '',
        ('Source: {0}' -f $installation.Source),
        ('Root: {0}' -f $installation.Root),
        '',
        ($targetLines -join [Environment]::NewLine)
    ) -join [Environment]::NewLine
    if ($existingTargets.Count -gt 0) {
        $prompt += [Environment]::NewLine + [Environment]::NewLine + 'WARNING: Existing q3key data will be replaced.'
    }
    $answer = [System.Windows.Forms.MessageBox]::Show(
        $form,
        $prompt,
        'Confirm key installation',
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Question
    )
    if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) {
        $status.Text = '> INSTALLATION CANCELLED. NOTHING WRITTEN.'
        return
    }
    try {
        $installed = @(Install-KeysToRoot $installation.Root $ArenaKey $TeamKey)
        $status.ForeColor = $acid
        $status.Text = '> {0} KEY(S) INSTALLED TO {1}.' -f $installed.Count,$installation.Source.ToUpperInvariant()
    } catch {
        $status.ForeColor = $bloodHot
        $status.Text = '> INSTALLATION FAILED. SEE ERROR MESSAGE.'
        [System.Windows.Forms.MessageBox]::Show(
            $form,$_.Exception.Message,'Key installation failed',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        ) | Out-Null
    }
}

$btnInstallArena.Add_Click({
    if (-not $arenaBox.Text) { $status.ForeColor = $bloodHot; $status.Text = '> ERROR: GENERATE AN ARENA KEY FIRST.'; return }
    & $installSelectedKeys $arenaBox.Text $null 1 'the Arena key'
})
$btnInstallTeam.Add_Click({
    if (-not $teamBox.Text) { $status.ForeColor = $bloodHot; $status.Text = '> ERROR: GENERATE A TEAM ARENA KEY FIRST.'; return }
    & $installSelectedKeys $null (Get-RawTeamArenaKey $teamBox.Text) 1 'the Team Arena key'
})
$btnInstallBoth.Add_Click({
    if (-not $arenaBox.Text -or -not $teamBox.Text) { $status.ForeColor = $bloodHot; $status.Text = '> ERROR: GENERATE BOTH KEYS FIRST.'; return }
    & $installSelectedKeys $arenaBox.Text (Get-RawTeamArenaKey $teamBox.Text) 2 'both generated keys'
})
$btnRescan.Add_Click({ Refresh-InstallationList })
$form.Add_KeyDown({ if ($_.KeyCode -eq [System.Windows.Forms.Keys]::Escape) { $form.Close() } })
$form.Add_Shown({ $form.Activate(); Refresh-InstallationList })
[void]$form.ShowDialog()
