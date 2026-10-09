# Measures the real rendered pixels of a card edge, from a screenshot taken on
# the device. This is the scanline `FEATURE.md` section 18.5 has asked for and
# that `shadow_balance_probe_test.dart` cannot provide, because that probe
# composites each shadow at full strength and therefore ignores the mask blur.
#
# The blur eats a different fraction of each page's shadow, so the same alpha
# lands on different visible steps on a bright page than on a dark one. That is
# how Dracula's dark half was solved to an arithmetic relation, measured at 52%
# of it on the real screen, and passed every test in between.
#
# Usage (PowerShell):
#   .\tool\scanline.ps1 <screenshot.png> <label>
#
# Prints. It asserts nothing: turning these numbers into thresholds is the
# decision this exists to inform.

param(
  [Parameter(Mandatory = $true)][string]$Image,
  [string]$Label = 'shot'
)

Add-Type -AssemblyName System.Drawing

$bmp = [System.Drawing.Bitmap]::FromFile((Resolve-Path $Image).Path)
try {
  # Sample a vertical strip through the middle of the card, where the top edge
  # and its shadow below it are both on one column.
  $x = [int]($bmp.Width / 2)

  # Find the card's top edge: the first row scanning down from 25% height whose
  # luminance departs from the page above it.
  function Luma([int]$px, [int]$py) {
    $c = $bmp.GetPixel($px, $py)
    $r = $c.R / 255.0; $g = $c.G / 255.0; $b = $c.B / 255.0
    $f = { param($s) if ($s -le 0.03928) { $s / 12.92 } else { $v = ($s + 0.055) / 1.055; $v * $v } }
    0.2126 * (& $f $r) + 0.7152 * (& $f $g) + 0.0722 * (& $f $b)
  }

  $start = [int]($bmp.Height * 0.20)
  $rows = @()
  for ($y = $start; $y -lt $start + 220; $y++) {
    $rows += [pscustomobject]@{ Y = $y; L = (Luma $x $y) }
  }

  $pageL = $rows[0].L
  $darkest = ($rows | Measure-Object -Property L -Minimum).Minimum
  $brightest = ($rows | Measure-Object -Property L -Maximum).Maximum

  Write-Host ""
  Write-Host "  --- $Label  $($bmp.Width)x$($bmp.Height), column x=$x"
  Write-Host ("     page      L = {0:F5}" -f $pageL)
  Write-Host ("     darkest   L = {0:F5}   dL = {1:F5}" -f $darkest, ($darkest - $pageL))
  Write-Host ("     brightest L = {0:F5}   dL = {1:F5}" -f $brightest, ($brightest - $pageL))

  $darkStep = $pageL - $darkest
  $lightStep = $brightest - $pageL
  if ($darkStep -gt 0) {
    Write-Host ("     measured light/dark = {0:F3}" -f ($lightStep / $darkStep))
  } else {
    Write-Host "     (no dark shadow found on this column)"
  }

  # 8-bit quantisation: one step here is 1/255, and the docs say the hue
  # tolerances in the tests are 0.5 degrees because of exactly this.
  Write-Host ("     quantisation floor = {0:F5} (1/255 of full scale)" -f (1.0 / 255.0))
}
finally {
  $bmp.Dispose()
}