Add-Type -AssemblyName System.Windows.Forms, System.Drawing
Add-Type -Namespace Win -Name Dpi -MemberDefinition '[DllImport("user32.dll")] public static extern bool SetProcessDPIAware();'
[void][Win.Dpi]::SetProcessDPIAware()   # without this Windows bitmap-scales the window and it looks blurry

$cfgPath = Join-Path $PSScriptRoot 'config.json'
$startupLnk = Join-Path ([Environment]::GetFolderPath('Startup')) 'WorldClock.lnk'

# --- config ---------------------------------------------------------------
$cfg = [pscustomobject]@{
    X = -1; Y = -1; Opacity = 0.92; TopMost = $true; Hour24 = $true
    Clocks = @(
        [pscustomobject]@{ Name = 'Local';    Id = 'local' },
        [pscustomobject]@{ Name = 'New York'; Id = 'Eastern Standard Time' },
        [pscustomobject]@{ Name = 'Taipei';   Id = 'Taipei Standard Time' },
        [pscustomobject]@{ Name = 'Sydney';   Id = 'AUS Eastern Standard Time' },
        [pscustomobject]@{ Name = 'UTC';      Id = 'UTC' }
    )
}
if (Test-Path $cfgPath) {
    try {
        $loaded = Get-Content $cfgPath -Raw | ConvertFrom-Json
        foreach ($p in 'X', 'Y', 'Opacity', 'TopMost', 'Hour24', 'Clocks') {
            if ($null -ne $loaded.$p) { $cfg.$p = $loaded.$p }
        }
    } catch { }
}
function Save-Config { $cfg | ConvertTo-Json -Depth 4 | Set-Content $cfgPath -Encoding UTF8 }

# --- time zones -----------------------------------------------------------
function Load-Zones {
    $script:zones = @(foreach ($c in $cfg.Clocks) {
        try {
            $tz = if ($c.Id -eq 'local') { [TimeZoneInfo]::Local } else { [TimeZoneInfo]::FindSystemTimeZoneById($c.Id) }
            [pscustomobject]@{ Name = $c.Name; Tz = $tz }
        } catch { }
    })
}
Load-Zones

# --- window ---------------------------------------------------------------
$rowH = 58; $pad = 8; $w = 270
$form = New-Object System.Windows.Forms.Form
$form.FormBorderStyle = 'None'
$form.ShowInTaskbar = $false
$form.StartPosition = 'Manual'
$g0 = $form.CreateGraphics(); $sc = $g0.DpiX / 96; $g0.Dispose()
$form.ClientSize = New-Object System.Drawing.Size([int]($w * $sc), [int](($rowH * $zones.Count + $pad * 2) * $sc))
$form.BackColor = [System.Drawing.Color]::FromArgb(24, 26, 32)
$form.Opacity = $cfg.Opacity
$form.TopMost = [bool]$cfg.TopMost
# DoubleBuffered is protected; set the paint styles through reflection to stop flicker
$styles = [System.Windows.Forms.ControlStyles]::OptimizedDoubleBuffer -bor [System.Windows.Forms.ControlStyles]::AllPaintingInWmPaint -bor [System.Windows.Forms.ControlStyles]::UserPaint
[System.Windows.Forms.Control].GetMethod('SetStyle', [Reflection.BindingFlags]'NonPublic,Instance').Invoke($form, @($styles, $true))

$area = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
$px = $area.Right - $form.Width - 20; $py = $area.Top + 20
if ($cfg.X -ge 0 -and $cfg.Y -ge 0 -and $cfg.X -lt ($area.Right - 40) -and $cfg.Y -lt ($area.Bottom - 40)) { $px = $cfg.X; $py = $cfg.Y }
$form.Location = New-Object System.Drawing.Point($px, $py)

# pixel units: the paint handler already scales by DPI, point sizes would be scaled twice
$pxUnit = [System.Drawing.GraphicsUnit]::Pixel; $reg = [System.Drawing.FontStyle]::Regular
$fName = New-Object System.Drawing.Font('Segoe UI', 15, $reg, $pxUnit)
$fTime = New-Object System.Drawing.Font('Segoe UI Semibold', 26, $reg, $pxUnit)
$fSub  = New-Object System.Drawing.Font('Segoe UI Semibold', 14, $reg, $pxUnit)
$bWhite = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
$bGray  = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(190, 196, 210))
$bDay   = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 200, 60))
$bNight = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(110, 130, 200))
$bBack  = New-Object System.Drawing.SolidBrush($form.BackColor)
$cDawn = [System.Drawing.Color]::FromArgb(255, 214, 140); $cSunset = [System.Drawing.Color]::FromArgb(255, 112, 60)
$bDawn = New-Object System.Drawing.SolidBrush($cDawn); $bSunset = New-Object System.Drawing.SolidBrush($cSunset)
$penDawn = New-Object System.Drawing.Pen($cDawn, 2); $penSunset = New-Object System.Drawing.Pen($cSunset, 2)
$penRay =New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255, 200, 60), 2)
$en = [System.Globalization.CultureInfo]::GetCultureInfo('en-US')
$penLine =New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(50, 54, 64))
$penEdge = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(70, 76, 90))
$right = New-Object System.Drawing.StringFormat
$right.Alignment = 'Far'

$form.Add_Paint({
    param($s, $e)
    $g = $e.Graphics
    $g.TextRenderingHint = 'AntiAliasGridFit'
    $g.SmoothingMode = 'AntiAlias'
    $g.ScaleTransform($sc, $sc)
    $utc = [DateTime]::UtcNow
    $localOff = [TimeZoneInfo]::Local.GetUtcOffset($utc)
    for ($i = 0; $i -lt $zones.Count; $i++) {
        $z = $zones[$i]
        $t = [TimeZoneInfo]::ConvertTimeFromUtc($utc, $z.Tz)
        $y = $pad + $i * $rowH
        $hr = $t.Hour
        $phase = if ($hr -ge 5 -and $hr -lt 7) { 'dawn' } elseif ($hr -ge 7 -and $hr -lt 17) { 'day' } elseif ($hr -ge 17 -and $hr -lt 19) { 'sunset' } else { 'night' }
        $cy = $y + 29
        if ($phase -eq 'dawn' -or $phase -eq 'sunset') {
            # half sun on the horizon: pale gold at dawn, deep orange at sunset
            $hb = if ($phase -eq 'dawn') { $bDawn } else { $bSunset }
            $hp = if ($phase -eq 'dawn') { $penDawn } else { $penSunset }
            $hy = $cy + 6
            $g.FillPie($hb, 15, ($hy - 9), 18, 18, 180, 180)
            foreach ($a in 0..4) {
                $r = [math]::PI + $a * [math]::PI / 4
                $g.DrawLine($hp, [single](24 + 12 * [math]::Cos($r)), [single]($hy + 12 * [math]::Sin($r)), [single](24 + 15 * [math]::Cos($r)), [single]($hy + 15 * [math]::Sin($r)))
            }
            $g.DrawLine($hp, 10, $hy, 38, $hy)
        } elseif ($phase -eq 'day') {
            $g.FillEllipse($bDay, 17, ($cy - 7), 14, 14)
            foreach ($a in 0..7) {
                $r = $a * [math]::PI / 4
                $g.DrawLine($penRay, [single](24 + 10 * [math]::Cos($r)), [single]($cy + 10 * [math]::Sin($r)), [single](24 + 13 * [math]::Cos($r)), [single]($cy + 13 * [math]::Sin($r)))
            }
        } else {
            $g.FillEllipse($bNight, 13, ($cy - 11), 22, 22)
            $g.FillEllipse($bBack, 21, ($cy - 15), 20, 20)
        }
        $g.DrawString($z.Name, $fName, $bWhite, 44, ($y + 3))
        $diff = $z.Tz.GetUtcOffset($utc) - $localOff
        $sub = $t.ToString('ddd, MMM d', $en)
        if ($diff.TotalMinutes -ne 0) {
            $sign = if ($diff.TotalMinutes -gt 0) { '+' } else { '-' }
            $sub += "   $sign$([math]::Abs($diff.TotalHours))h"
        }
        $g.DrawString($sub, $fSub, $bGray, 44, ($y + 31))
        if ($cfg.Hour24) {
            $g.DrawString($t.ToString('HH:mm', $en), $fTime, $bWhite, [single]($w - 12), ($y + 8), $right)
        } else {
            $g.DrawString($t.ToString('h:mm', $en), $fTime, $bWhite, [single]($w - 48), ($y + 8), $right)
            $g.DrawString($t.ToString('tt', $en), $fSub, $bGray, [single]($w - 46), ($y + 21))
        }
        if ($i -lt $zones.Count - 1) { $g.DrawLine($penLine, 14, ($y + $rowH - 1), ($w - 14), ($y + $rowH - 1)) }
    }
    $g.DrawRectangle($penEdge, 0, 0, ($w - 1), ($rowH * $zones.Count + $pad * 2 - 1))
})

# only repaint when the displayed minute changes
$script:lastMin = ''
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 1000
$timer.Add_Tick({
    $m = [DateTime]::UtcNow.ToString('yyyyMMddHHmm')
    if ($m -ne $script:lastMin) { $script:lastMin = $m; $form.Invalidate() }
})
$timer.Start()

# --- drag to move ---------------------------------------------------------
$script:drag = $null
$form.Add_MouseDown({ param($s, $e) if ($e.Button -eq 'Left') { $script:drag = $e.Location } })
$form.Add_MouseMove({
    param($s, $e)
    if ($script:drag) {
        $form.Location = New-Object System.Drawing.Point(($form.Left + $e.X - $script:drag.X), ($form.Top + $e.Y - $script:drag.Y))
    }
})
$form.Add_MouseUp({
    $script:drag = $null
    $cfg.X = $form.Left; $cfg.Y = $form.Top
    Save-Config
})

# --- city picker ----------------------------------------------------------
$slots = 5
function Show-CityDialog {
    $all = [TimeZoneInfo]::GetSystemTimeZones()
    $script:ids = @('local') + @($all | ForEach-Object { $_.Id })
    $labels = @('Local time (this PC)') + @($all | ForEach-Object { $_.DisplayName })

    $dlg = New-Object System.Windows.Forms.Form
    $dlg.Text = "Choose $slots cities / time zones"
    $dlg.FormBorderStyle = 'FixedDialog'
    $dlg.StartPosition = 'CenterScreen'
    $dlg.MaximizeBox = $false; $dlg.MinimizeBox = $false
    $dlg.TopMost = $true
    $dlg.Font = New-Object System.Drawing.Font('Segoe UI', 9)
    $dlg.AutoScaleDimensions = New-Object System.Drawing.SizeF(96, 96)
    $dlg.AutoScaleMode = 'Dpi'
    $dlg.ClientSize = New-Object System.Drawing.Size(560, (50 + $slots * 36 + 56))

    $h1 = New-Object System.Windows.Forms.Label; $h1.Text = 'Label'; $h1.Location = '14,14'; $h1.AutoSize = $true
    $h2 = New-Object System.Windows.Forms.Label; $h2.Text = 'Time zone'; $h2.Location = '170,14'; $h2.AutoSize = $true
    $dlg.Controls.AddRange(@($h1, $h2))

    $rows = @()
    for ($i = 0; $i -lt $slots; $i++) {
        $y = 40 + $i * 36
        $tb = New-Object System.Windows.Forms.TextBox
        $tb.Location = New-Object System.Drawing.Point(14, $y); $tb.Width = 144; $tb.MaxLength = 20
        $cb = New-Object System.Windows.Forms.ComboBox
        $cb.DropDownStyle = 'DropDownList'
        $cb.Location = New-Object System.Drawing.Point(170, $y); $cb.Width = 376
        [void]$cb.Items.AddRange($labels)
        $cb.Tag = $tb
        $cur = if ($i -lt $cfg.Clocks.Count) { $cfg.Clocks[$i] } else { $null }
        $idx = if ($cur) { [array]::IndexOf($script:ids, $cur.Id) } else { 0 }
        $cb.SelectedIndex = [math]::Max($idx, 0)
        $tb.Text = if ($cur) { $cur.Name } else { 'Local' }
        $tb.Tag = $tb.Text   # last auto-filled name; replaced only if the user hasn't typed their own
        $cb.Add_SelectedIndexChanged({
            param($s, $e)
            $box = $s.Tag
            if ($box.Text -eq '' -or $box.Text -eq $box.Tag) {
                $n = if ($s.SelectedIndex -eq 0) { 'Local' } else { ($s.Text -replace '^\([^)]*\)\s*', '') -replace '\s*\(.*$', '' }
                $box.Text = $n; $box.Tag = $n
            }
        })
        $dlg.Controls.AddRange(@($tb, $cb))
        $rows += , @($tb, $cb)
    }

    $ok = New-Object System.Windows.Forms.Button
    $ok.Text = 'OK'; $ok.DialogResult = 'OK'
    $ok.Location = New-Object System.Drawing.Point(376, (50 + $slots * 36 + 10))
    $cancel = New-Object System.Windows.Forms.Button
    $cancel.Text = 'Cancel'; $cancel.DialogResult = 'Cancel'
    $cancel.Location = New-Object System.Drawing.Point(466, (50 + $slots * 36 + 10))
    $dlg.Controls.AddRange(@($ok, $cancel))
    $dlg.AcceptButton = $ok; $dlg.CancelButton = $cancel

    if ($dlg.ShowDialog() -eq 'OK') {
        $cfg.Clocks = @(foreach ($r in $rows) {
            $name = $r[0].Text.Trim()
            if ($name -eq '') { $name = 'Local' }
            [pscustomobject]@{ Name = $name; Id = $script:ids[$r[1].SelectedIndex] }
        })
        Save-Config
        Load-Zones
        $form.ClientSize = New-Object System.Drawing.Size([int]($w * $sc), [int](($rowH * $zones.Count + $pad * 2) * $sc))
        $form.Invalidate()
    }
    $dlg.Dispose()
}

# --- right-click menu -----------------------------------------------------
$menu = New-Object System.Windows.Forms.ContextMenuStrip

$miCities = New-Object System.Windows.Forms.ToolStripMenuItem("Choose $slots cities...")
$miCities.Add_Click({ Show-CityDialog })
[void]$menu.Items.Add($miCities)
[void]$menu.Items.Add('-')

$miTop = New-Object System.Windows.Forms.ToolStripMenuItem('Always on top')
$miTop.CheckOnClick = $true
$miTop.Checked = [bool]$cfg.TopMost
$miTop.Add_Click({ $form.TopMost = $miTop.Checked; $cfg.TopMost = $miTop.Checked; Save-Config })
[void]$menu.Items.Add($miTop)

$mi24 = New-Object System.Windows.Forms.ToolStripMenuItem('24-hour time')
$mi24.CheckOnClick = $true
$mi24.Checked = [bool]$cfg.Hour24
$mi24.Add_Click({ $cfg.Hour24 = $mi24.Checked; Save-Config; $form.Invalidate() })
[void]$menu.Items.Add($mi24)

$miOp = New-Object System.Windows.Forms.ToolStripMenuItem('Opacity')
foreach ($pct in 100, 90, 75, 60, 40) {
    $item = New-Object System.Windows.Forms.ToolStripMenuItem("$pct%")
    $item.Tag = $pct / 100
    $item.Add_Click({
        param($s, $e)
        $form.Opacity = $s.Tag; $cfg.Opacity = $s.Tag; Save-Config
    })
    [void]$miOp.DropDownItems.Add($item)
}
[void]$menu.Items.Add($miOp)

$miStart = New-Object System.Windows.Forms.ToolStripMenuItem('Start with Windows')
$miStart.CheckOnClick = $true
$miStart.Checked = Test-Path $startupLnk
$miStart.Add_Click({
    if ($miStart.Checked) {
        $sh = (New-Object -ComObject WScript.Shell).CreateShortcut($startupLnk)
        $sh.TargetPath = 'powershell.exe'
        $sh.Arguments = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$PSCommandPath`""
        $sh.WorkingDirectory = $PSScriptRoot
        $sh.WindowStyle = 7
        $sh.Save()
    } elseif (Test-Path $startupLnk) {
        Remove-Item $startupLnk
    }
})
[void]$menu.Items.Add($miStart)

[void]$menu.Items.Add('-')
$miExit = New-Object System.Windows.Forms.ToolStripMenuItem('Exit')
$miExit.Add_Click({ $form.Close() })
[void]$menu.Items.Add($miExit)
$form.ContextMenuStrip = $menu

[void][System.Windows.Forms.Application]::Run($form)
