[CmdletBinding()]
param([switch]$SelfTest)

Set-StrictMode -Version 2.0
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
    Write-Output 'PASS: generated 100 valid Arena and Team Arena key pairs.'
    exit 0
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

# Late-90s shooter palette: scorched iron, rust, bone and blood.
$void = [System.Drawing.Color]::FromArgb(12,10,9)
$iron = [System.Drawing.Color]::FromArgb(38,34,29)
$ironDark = [System.Drawing.Color]::FromArgb(18,16,14)
$blood = [System.Drawing.Color]::FromArgb(132,8,5)
$bloodHot = [System.Drawing.Color]::FromArgb(220,28,12)
$rust = [System.Drawing.Color]::FromArgb(205,91,24)
$bone = [System.Drawing.Color]::FromArgb(219,205,166)
$ash = [System.Drawing.Color]::FromArgb(127,118,100)
$acid = [System.Drawing.Color]::FromArgb(194,205,67)
$black = [System.Drawing.Color]::FromArgb(5,4,3)

function New-UiFont([float]$Size, [System.Drawing.FontStyle]$Style = [System.Drawing.FontStyle]::Regular) {
    New-Object System.Drawing.Font('Arial Narrow',$Size,$Style)
}

function New-RetroButton([string]$Text,[int]$X,[int]$Y,[int]$Width,[int]$Height,[System.Drawing.Color]$Accent = $rust) {
    $button = New-Object System.Windows.Forms.Button
    $button.Text = $Text
    $button.Size = New-Object System.Drawing.Size($Width,$Height)
    $button.Location = New-Object System.Drawing.Point($X,$Y)
    $button.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $button.FlatAppearance.BorderColor = $Accent
    $button.FlatAppearance.BorderSize = 1
    $button.FlatAppearance.MouseOverBackColor = [System.Drawing.Color]::FromArgb(65,24,18)
    $button.FlatAppearance.MouseDownBackColor = $blood
    $button.BackColor = $ironDark
    $button.ForeColor = $bone
    $button.Font = New-UiFont 9 ([System.Drawing.FontStyle]::Bold)
    $button.Cursor = [System.Windows.Forms.Cursors]::Hand
    $button.TabStop = $false
    $button.Add_MouseEnter({ $this.ForeColor = $bloodHot })
    $button.Add_MouseLeave({ $this.ForeColor = $bone })
    $button
}

function Select-KeySavePath([string]$Title,[string]$SuggestedDirectory) {
    $repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
    $candidate = Join-Path $repositoryRoot $SuggestedDirectory
    $initialDirectory = if (Test-Path -LiteralPath $candidate) { $candidate } else { $repositoryRoot }

    $dialog = New-Object System.Windows.Forms.SaveFileDialog
    $dialog.Title = $Title
    $dialog.Filter = 'Quake III key file (q3key)|q3key|All files (*.*)|*.*'
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

function Write-KeyFile([string]$Path,[string]$Key) {
    $Key | Set-Content -LiteralPath $Path -Encoding ASCII -NoNewline
}

function New-SectionPanel([string]$Heading,[string]$PathText,[int]$Y,[System.Drawing.Color]$Accent) {
    $panel = New-Object System.Windows.Forms.Panel
    $panel.Location = New-Object System.Drawing.Point(24,$Y)
    $panel.Size = New-Object System.Drawing.Size(576,116)
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
    $pathLabel.Location = New-Object System.Drawing.Point(23,39)
    $panel.Controls.Add($pathLabel)
    $panel
}

$form = New-Object System.Windows.Forms.Form
$form.Text = 'SpiRaL'' // Q3 KEY FORGE'
$form.ClientSize = New-Object System.Drawing.Size(624,510)
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
    $headerRect = New-Object System.Drawing.Rectangle(0,0,$sender.ClientSize.Width,100)
    $topBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush($headerRect,[System.Drawing.Color]::FromArgb(58,20,13),$void,90)
    $bloodBrush = New-Object System.Drawing.SolidBrush($blood)
    $hotBrush = New-Object System.Drawing.SolidBrush($bloodHot)
    $scratchPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(65,58,48),1)
    $edgePen = New-Object System.Drawing.Pen($rust,1)
    try {
        $graphics.FillRectangle($topBrush,0,0,$sender.ClientSize.Width,100)
        $graphics.DrawRectangle($edgePen,8,8,$sender.ClientSize.Width-17,$sender.ClientSize.Height-17)
        $bloodPoints = [System.Drawing.Point[]]@(
            (New-Object System.Drawing.Point(0,55)),(New-Object System.Drawing.Point(165,34)),
            (New-Object System.Drawing.Point(360,48)),(New-Object System.Drawing.Point(624,26)),
            (New-Object System.Drawing.Point(624,42)),(New-Object System.Drawing.Point(350,63)),
            (New-Object System.Drawing.Point(155,50)),(New-Object System.Drawing.Point(0,72)))
        $graphics.FillPolygon($bloodBrush,$bloodPoints)
        foreach ($drip in @(@(88,52,7,26),@(274,55,10,39),@(490,44,6,20),@(535,40,12,31))) {
            $graphics.FillRectangle($bloodBrush,$drip[0],$drip[1],$drip[2],$drip[3])
            $graphics.FillEllipse($hotBrush,$drip[0],$drip[1]+$drip[3]-3,$drip[2],8)
        }
        foreach ($scratch in @(@(18,112,240,90),@(382,104,590,75),@(35,452,240,425),@(405,470,602,440),@(160,95,305,80),@(330,495,510,475))) {
            $graphics.DrawLine($scratchPen,$scratch[0],$scratch[1],$scratch[2],$scratch[3])
        }
    } finally {
        $topBrush.Dispose(); $bloodBrush.Dispose(); $hotBrush.Dispose()
        $scratchPen.Dispose(); $edgePen.Dispose()
    }
})

$titleShadow = New-Object System.Windows.Forms.Label
$titleShadow.Text = 'Q3 KEY FORGE'
$titleShadow.Font = New-UiFont 25 ([System.Drawing.FontStyle]::Bold)
$titleShadow.ForeColor = $black
$titleShadow.BackColor = [System.Drawing.Color]::Transparent
$titleShadow.AutoSize = $true
$titleShadow.Location = New-Object System.Drawing.Point(178,19)
$form.Controls.Add($titleShadow)

$title = New-Object System.Windows.Forms.Label
$title.Text = 'Q3 KEY FORGE'
$title.Font = New-UiFont 25 ([System.Drawing.FontStyle]::Bold)
$title.ForeColor = $bone
$title.BackColor = [System.Drawing.Color]::Transparent
$title.AutoSize = $true
$title.Location = New-Object System.Drawing.Point(175,16)
$form.Controls.Add($title)
$title.BringToFront()

$subtitle = New-Object System.Windows.Forms.Label
$subtitle.Text = 'ARENA + TEAM ARENA // SpiRaL'' // 1999 NEVER DIED'
$subtitle.Font = New-UiFont 8 ([System.Drawing.FontStyle]::Bold)
$subtitle.ForeColor = $rust
$subtitle.BackColor = [System.Drawing.Color]::Transparent
$subtitle.AutoSize = $true
$subtitle.Location = New-Object System.Drawing.Point(155,65)
$form.Controls.Add($subtitle)

$arenaPanel = New-SectionPanel 'I. QUAKE III ARENA' 'TARGET  baseq3\q3key' 104 $rust
$form.Controls.Add($arenaPanel)
$arenaBox = New-Object System.Windows.Forms.TextBox
$arenaBox.Font = New-UiFont 16 ([System.Drawing.FontStyle]::Bold)
$arenaBox.Size = New-Object System.Drawing.Size(328,32)
$arenaBox.Location = New-Object System.Drawing.Point(22,66)
$arenaBox.TextAlign = [System.Windows.Forms.HorizontalAlignment]::Center
$arenaBox.ReadOnly = $true
$arenaBox.BackColor = $black
$arenaBox.ForeColor = $bone
$arenaBox.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$arenaPanel.Controls.Add($arenaBox)
$btnArena = New-RetroButton 'FORGE' 360 65 88 32 $rust
$arenaPanel.Controls.Add($btnArena)
$btnSaveArena = New-RetroButton 'WRITE' 457 65 96 32 $bloodHot
$arenaPanel.Controls.Add($btnSaveArena)

$teamPanel = New-SectionPanel 'II. QUAKE III TEAM ARENA' 'TARGET  missionpack\q3key  // checksum display' 230 $bloodHot
$form.Controls.Add($teamPanel)
$teamBox = New-Object System.Windows.Forms.TextBox
$teamBox.Font = New-UiFont 16 ([System.Drawing.FontStyle]::Bold)
$teamBox.Size = New-Object System.Drawing.Size(328,32)
$teamBox.Location = New-Object System.Drawing.Point(22,66)
$teamBox.TextAlign = [System.Windows.Forms.HorizontalAlignment]::Center
$teamBox.ReadOnly = $true
$teamBox.BackColor = $black
$teamBox.ForeColor = $bloodHot
$teamBox.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$teamPanel.Controls.Add($teamBox)
$btnTeam = New-RetroButton 'FORGE' 360 65 88 32 $rust
$teamPanel.Controls.Add($btnTeam)
$btnSaveTeam = New-RetroButton 'WRITE' 457 65 96 32 $bloodHot
$teamPanel.Controls.Add($btnSaveTeam)

$btnBoth = New-RetroButton 'FORGE BOTH' 24 362 280 44 $rust
$btnBoth.Font = New-UiFont 12 ([System.Drawing.FontStyle]::Bold)
$form.Controls.Add($btnBoth)
$btnSaveBoth = New-RetroButton 'WRITE BOTH' 320 362 280 44 $bloodHot
$btnSaveBoth.Font = New-UiFont 12 ([System.Drawing.FontStyle]::Bold)
$form.Controls.Add($btnSaveBoth)

$statusPanel = New-Object System.Windows.Forms.Panel
$statusPanel.Location = New-Object System.Drawing.Point(24,420)
$statusPanel.Size = New-Object System.Drawing.Size(576,39)
$statusPanel.BackColor = $black
$form.Controls.Add($statusPanel)
$status = New-Object System.Windows.Forms.Label
$status.Text = '> SYSTEM READY. CHOOSE YOUR GAME.'
$status.Font = New-UiFont 9 ([System.Drawing.FontStyle]::Bold)
$status.ForeColor = $acid
$status.AutoSize = $true
$status.Location = New-Object System.Drawing.Point(12,11)
$statusPanel.Controls.Add($status)

$footer = New-Object System.Windows.Forms.Label
$footer.Text = 'GPL-2.0 // OFFLINE TOOL // ESC TO EXIT'
$footer.Font = New-UiFont 7
$footer.ForeColor = $ash
$footer.BackColor = [System.Drawing.Color]::Transparent
$footer.AutoSize = $true
$footer.Location = New-Object System.Drawing.Point(199,477)
$form.Controls.Add($footer)

$btnArena.Add_Click({
    $arenaBox.Text = New-ArenaKey
    [System.Windows.Forms.Clipboard]::SetText($arenaBox.Text)
    $status.ForeColor = $rust
    $status.Text = '> ARENA KEY FORGED + COPIED TO CLIPBOARD.'
})
$btnTeam.Add_Click({
    $teamBox.Text = New-TeamArenaKey
    [System.Windows.Forms.Clipboard]::SetText($teamBox.Text)
    $status.ForeColor = $bloodHot
    $status.Text = '> TEAM ARENA KEY FORGED + COPIED TO CLIPBOARD.'
})
$btnBoth.Add_Click({
    $arenaBox.Text = New-ArenaKey
    $teamBox.Text = New-TeamArenaKey
    $clipboardText = '{0}{1}{2}' -f $arenaBox.Text,[Environment]::NewLine,$teamBox.Text
    [System.Windows.Forms.Clipboard]::SetText($clipboardText)
    $status.ForeColor = $acid
    $status.Text = '> BOTH KEYS FORGED + COPIED TO CLIPBOARD.'
})
$btnSaveArena.Add_Click({
    if (-not $arenaBox.Text) {
        $status.ForeColor = $bloodHot
        $status.Text = '> ERROR: FORGE AN ARENA KEY FIRST.'
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
        $status.Text = '> ERROR: FORGE A TEAM ARENA KEY FIRST.'
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
        $status.Text = '> ERROR: FORGE BOTH KEYS FIRST.'
        return
    }
    $arenaSavePath = Select-KeySavePath 'Save Quake III Arena key' 'baseq3'
    if (-not $arenaSavePath) { $status.Text = '> SAVE CANCELLED.'; return }
    $teamSavePath = Select-KeySavePath 'Save Quake III Team Arena key' 'missionpack'
    if (-not $teamSavePath) { $status.Text = '> SAVE CANCELLED. NOTHING WRITTEN.'; return }
    if ([System.IO.Path]::GetFullPath($arenaSavePath) -eq [System.IO.Path]::GetFullPath($teamSavePath)) {
        $status.ForeColor = $bloodHot
        $status.Text = '> ERROR: CHOOSE TWO DIFFERENT FILES.'
        return
    }
    Write-KeyFile $arenaSavePath $arenaBox.Text
    Write-KeyFile $teamSavePath (Get-RawTeamArenaKey $teamBox.Text)
    $status.ForeColor = $acid
    $status.Text = '> BOTH KEY FILES SAVED. RIP AND TEAR.'
})
$form.Add_KeyDown({ if ($_.KeyCode -eq [System.Windows.Forms.Keys]::Escape) { $form.Close() } })
$form.Add_Shown({ $form.Activate() })
[void]$form.ShowDialog()
