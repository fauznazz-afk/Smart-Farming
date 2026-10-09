# Measures the shadow a card actually casts, from a screenshot taken on the real
# device.
#
# Why this exists: `shadow_balance_probe_test.dart` composites each shadow at full
# strength, which ignores the mask blur, and the blur eats a different fraction of
# each page's shadow. That is how Dracula's dark half was solved to an arithmetic
# relation, then measured at 52% of it on the real screen, passing every test in
# between. A pixel measurement is the only kind that settles it.
#
#   .\tool\scanline.ps1 <screenshot.png> <label> [xFraction]
#
# Prints. It asserts nothing: turning these numbers into thresholds is the
# decision this exists to inform.
#
# Two versions of this script measured something other than a shadow before this
# one, and both are worth not repeating:
#
#   1. Sampling a fixed vertical window and taking min/max luminance. On the
#      Appearance screen that window ran straight through the palette icons, and
#      the "darkest" pixel was antialiased icon ink at L=0.06, so it reported a
#      light/dark ratio of 0.024. That number is the contrast of a tick mark
#      against a button, not of a shadow against a page.
#   2. Sampling the centre column. On that screen the centre column happens to be
#      where the check-mark icon is.
#
# So this locates the card's top edge by scanning for the largest single-row
# luminance step, then samples a short run just OUTSIDE that edge - which is the
# only region where a drop shadow exists and content does not.

param(
  [Parameter(Mandatory = $true)][string]$Image,
  [string]$Label = 'shot',
  [double]$xFraction = 0.5
)

Add-Type -AssemblyName System.Drawing

$script:bm = [System.Drawing.Bitmap]::FromFile((Resolve-Path $Image).Path)

function Luma([int]$px, [int]$py) {
  $c = $script:bm.GetPixel($px, $py)
  $f = {
    param($s)
    if ($s -le 0.03928) { $s / 12.92 } else { $v = ($s + 0.055) / 1.055; $v * $v }
  }
  $r = & $f ($c.R / 255.0)
  $g = & $f ($c.G / 255.0)
  $b = & $f ($c.B / 255.0)
  0.2126 * $r + 0.7152 * $g + 0.0722 * $b
}

try {
  $W = $script:bm.Width
  $H = $script:bm.Height
  $x = [int]($W * $xFraction)

  # 1. Find the strongest single-row luminance step in the middle band. A card's
  #    top edge is the one place a soft-UI page changes sharply, because the fill
  #    is opaque and the page behind it is not.
  $top = [int]($H * 0.10)
  $bottom = [int]($H * 0.60)
  $best = 0.0
  $edgeY = -1
  $prev = Luma $x $top
  for ($y = $top + 1; $y -lt $bottom; $y++) {
    $cur = Luma $x $y
    $step = [math]::Abs($cur - $prev)
    if ($step -gt $best) { $best = $step; $edgeY = $y }
    $prev = $cur
  }

  if ($edgeY -lt 0) {
    Write-Host "  --- ${Label}: no edge found on column x=$x"
    return
  }

  $pageL = Luma $x ($edgeY - 3)
  $cardL = Luma $x ($edgeY + 6)

  # 2. Sample the run just BELOW the card, where only its shadow can be. The
  #    ambient shadow is offset (9,9) with blur 22, so 14..70px down is inside it.
  $below = @()
  for ($y = $edgeY + 14; $y -le $edgeY + 70; $y++) {
    if ($y -lt $H) { $below += Luma $x $y }
  }
  $shadowDarkest = ($below | Measure-Object -Minimum).Minimum

  # 3. And the run just ABOVE it, where the light bounce lands. Offset (-6,-6),
  #    blur 14, so 8..40px up.
  $above = @()
  for ($y = $edgeY - 40; $y -le $edgeY - 8; $y++) {
    if ($y -ge 0) { $above += Luma $x $y }
  }
  $shadowBrightest = ($above | Measure-Object -Maximum).Maximum

  Write-Host ""
  Write-Host "  --- $Label   $($script:bm.Width)x$($script:bm.Height), column x=$x"
  Write-Host ("     card edge found at y={0}   page L={1:F5}   card L={2:F5}" -f $edgeY, $pageL, $cardL)
  Write-Host ("     card vs page fill:      dL={0:F5}" -f ($cardL - $pageL))
  Write-Host ("     dark half below edge:    dL={0:F5}" -f ($shadowDarkest - $pageL))
  Write-Host ("     light half above edge:   dL={0:F5}" -f ($shadowBrightest - $pageL))

  $darkStep = $pageL - $shadowDarkest
  $lightStep = $shadowBrightest - $pageL
  if ($darkStep -gt 0) {
    Write-Host ("     measured light/dark = {0:F3}" -f ($lightStep / $darkStep))
  } else {
    Write-Host "     (no dark shadow below the edge on this column - try another xFraction)"
  }
  Write-Host ("     8-bit quantisation floor = {0:F5}" -f (1.0 / 255.0))
}
finally {
  $script:bm.Dispose()
}