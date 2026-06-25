Add-Type -AssemblyName System.Drawing

$S = 1024  # canvas size

# Brand palette
$primary    = [System.Drawing.Color]::FromArgb(0x00,0x77,0xB6)
$primaryDeep= [System.Drawing.Color]::FromArgb(0x02,0x3E,0x8A)
$secondary  = [System.Drawing.Color]::FromArgb(0x00,0xB4,0xD8)
$tint       = [System.Drawing.Color]::FromArgb(0x48,0xCA,0xE4)
$bgLight    = [System.Drawing.Color]::FromArgb(0xCA,0xF0,0xF8)
$white      = [System.Drawing.Color]::White

function New-HeartPath([single]$cx, [single]$cy, [single]$w, [single]$h) {
    # Classic parametric heart, sampled to a smooth polygon
    $pts = New-Object System.Collections.Generic.List[System.Drawing.PointF]
    $minX=1e9; $maxX=-1e9; $minY=1e9; $maxY=-1e9
    $raw = @()
    for ($i=0; $i -le 240; $i++) {
        $t = $i / 240.0 * [Math]::PI * 2
        $x = 16 * [Math]::Pow([Math]::Sin($t),3)
        $y = 13*[Math]::Cos($t) - 5*[Math]::Cos(2*$t) - 2*[Math]::Cos(3*$t) - [Math]::Cos(4*$t)
        $raw += ,@($x,$y)
        if ($x -lt $minX){$minX=$x}; if ($x -gt $maxX){$maxX=$x}
        if ($y -lt $minY){$minY=$y}; if ($y -gt $maxY){$maxY=$y}
    }
    $rw = $maxX - $minX; $rh = $maxY - $minY
    foreach ($p in $raw) {
        $nx = ($p[0] - ($minX+$maxX)/2) / $rw      # -0.5..0.5
        $ny = ($p[1] - ($minY+$maxY)/2) / $rh      # -0.5..0.5 (math y up)
        $sx = $cx + $nx * $w
        $sy = $cy - $ny * $h                         # flip to screen
        $pts.Add([System.Drawing.PointF]::new($sx,$sy))
    }
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddPolygon($pts.ToArray())
    return $path
}

function New-PulsePath([single]$baseY, [single]$amp) {
    # ECG polyline across the heart's middle band. x as fraction of canvas.
    $defs = @(
        @(0.12,0), @(0.34,0), @(0.40,-0.16), @(0.45,0), @(0.485,0.26),
        @(0.525,-1.0), @(0.565,0.6), @(0.605,0), @(0.66,-0.20),
        @(0.72,0), @(0.88,0)
    )
    $pts = New-Object System.Collections.Generic.List[System.Drawing.PointF]
    foreach ($d in $defs) {
        $px = $d[0] * $S
        $py = $baseY + $d[1] * $amp
        $pts.Add([System.Drawing.PointF]::new($px,$py))
    }
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddLines($pts.ToArray())
    return $path
}

function Render-Icon([string]$variant, [string]$outPath) {
    $bmp = New-Object System.Drawing.Bitmap($S,$S)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode    = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.InterpolationMode= [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode  = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

    $rect = New-Object System.Drawing.RectangleF(0,0,$S,$S)

    if ($variant -eq 'blue') {
        $bgA = $primary; $bgB = $primaryDeep
        $heartA = $white; $heartB = $bgLight
        $accent = $secondary
    } else {
        $bgA = $bgLight; $bgB = [System.Drawing.Color]::FromArgb(0xE8,0xFA,0xFE)
        $heartA = $secondary; $heartB = $primary
        $accent = $tint
    }

    # ---- Background gradient (diagonal) ----
    $bgBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect, $bgA, $bgB, 55.0)
    $g.FillRectangle($bgBrush, $rect)

    # subtle radial-ish glow top-left for depth (light variant only gets a soft tint)
    # ---- Heart geometry ----
    $cx = 512.0; $cy = 478.0; $hw = 560.0; $hh = 540.0
    $heart = New-HeartPath $cx $cy $hw $hh

    # soft shadow under heart (blue variant)
    if ($variant -eq 'blue') {
        $shadow = New-HeartPath ($cx) ($cy+14) $hw $hh
        $shBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(60,0x01,0x1B,0x3A))
        $g.FillPath($shBrush, $shadow)
        $shadow.Dispose(); $shBrush.Dispose()
    }

    # ---- Pulse cut (true negative space) ----
    $pulseBaseY = 470.0
    $pulseAmp   = 165.0
    $pulse = New-PulsePath $pulseBaseY $pulseAmp
    $pen = New-Object System.Drawing.Pen($accent, 52.0)
    $pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $pen.EndCap   = [System.Drawing.Drawing2D.LineCap]::Round
    $pen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
    $pulseWide = $pulse.Clone()
    $pulseWide.Widen($pen)

    # Heart region minus pulse = cutout
    $heartRegion = New-Object System.Drawing.Region($heart)
    $pulseRegion = New-Object System.Drawing.Region($pulseWide)
    $heartRegion.Exclude($pulseRegion)

    $heartBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect, $heartA, $heartB, 115.0)
    $g.FillRegion($heartBrush, $heartRegion)

    # thin accent stroke along the pulse centerline (inside heart only) for a "fascinating" glow
    $g.SetClip($heart)
    $glowPen = New-Object System.Drawing.Pen($accent, 9.0)
    $glowPen.StartCap=[System.Drawing.Drawing2D.LineCap]::Round
    $glowPen.EndCap=[System.Drawing.Drawing2D.LineCap]::Round
    $glowPen.LineJoin=[System.Drawing.Drawing2D.LineJoin]::Round
    $g.DrawPath($glowPen, $pulse)
    $g.ResetClip()

    $g.Save() | Out-Null
    $bmp.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)

    $g.Dispose(); $bmp.Dispose()
    Write-Host "wrote $outPath"
}

$dir = Join-Path (Split-Path -Parent $PSScriptRoot) 'assets\icon'
Render-Icon 'blue'  (Join-Path $dir 'app_icon_blue.png')
Render-Icon 'light' (Join-Path $dir 'app_icon_light.png')

# side-by-side preview
$pv = New-Object System.Drawing.Bitmap(2100,1024)
$pg = [System.Drawing.Graphics]::FromImage($pv)
$pg.Clear([System.Drawing.Color]::FromArgb(0x20,0x20,0x28))
$b1 = [System.Drawing.Image]::FromFile((Join-Path $dir 'app_icon_blue.png'))
$b2 = [System.Drawing.Image]::FromFile((Join-Path $dir 'app_icon_light.png'))
$pg.DrawImage($b1, 10, 0, 1024, 1024)
$pg.DrawImage($b2, 1066, 0, 1024, 1024)
$b1.Dispose(); $b2.Dispose()
$pv.Save((Join-Path $dir '_preview.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$pg.Dispose(); $pv.Dispose()
Write-Host "wrote preview"
