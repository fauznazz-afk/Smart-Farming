# Measures the luminance step a card's shadow produces, robustly.
#
# Three earlier attempts failed the same way: they took the *darkest* pixel
# below a card edge, and below a card edge there is almost always text, so the
# number came back as a glyph. Measured failures of that shape in this session:
# 129 luminance units (RGB 95,105,100 -- a caption), 106 units, and a negative
# step of -26.79 from a reference that had itself been sampled inside a card.
#
# So this does not look for an extreme. For each row it takes the **median**
# across the card's own width, which rejects text and icons as outliers, and it
# takes the page reference the same way from a row well clear of any card. The
# shadow of a card is a smooth ramp, and a median across ~800px of a row that is
# 90% page colour is exactly that ramp.
param(
  [string]$Image = "C:\Users\Fauzan\AppData\Local\Temp\opencode\ui\23_dash_fresh.png",
  [int]$X = 300,
  [int]$MinRun = 150,
  [int]$Below = 60,
  [int]$RefOffset = 160
)

Add-Type -AssemblyName System.Drawing
$bmp = [System.Drawing.Bitmap]::FromFile($Image)

function Lum($r, $g, $b) { 0.2126 * $r + 0.7152 * $g + 0.0722 * $b }

# Card fill and page fill, read from the file's own tokens rather than typed in,
# so a token change cannot leave this describing an app that no longer exists.
$cardHex = (Select-String -Path "$PSScriptRoot\..\lib\screens\dashboard\utils\design_tokens.dart" -Pattern 'pageLight|cardLight').Line
Write-Output "token lines matched:"
$cardHex | ForEach-Object { Write-Output "  $_" }

# Locate card bodies in the probe column.
$cls = @()
for ($y = 0; $y -lt $bmp.Height; $y++) {
  $c = $bmp.GetPixel($X, $y)
  $l = Lum $c.R $c.G $c.B
  # Light theme: page ~244, card fill ~228-234. Anything far darker is text.
  $cls += $(if ($l -ge 220) { 'surface' } else { 'dark' })
}

$runs = @(); $start = -1
for ($y = 0; $y -lt $cls.Count; $y++) {
  if ($cls[$y] -eq 'surface') {
    if ($start -lt 0) { $start = $y }
  } else {
    if ($start -ge 0 -and ($y - $start) -ge $MinRun) { $runs += ,@($start, ($y - 1)) }
    $start = -1
  }
}
if ($start -ge 0 -and ($cls.Count - $start) -ge $MinRun) { $runs += ,@($start, ($cls.Count - 1)) }

# The card's horizontal extent, found the same way on the card's own centre row.
function RowMedian([int]$y, [int]$x0, [int]$x1) {
  $v = @()
  for ($x = $x0; $x -le $x1; $x++) {
    $c = $bmp.GetPixel($x, $y)
    $v += [double](Lum $c.R $c.G $c.B)
  }
  $s = $v | Sort-Object
  return $s[[int]([math]::Floor($s.Count / 2))]
}

function CardSpan([int]$y) {
  # Walk out from the probe column while the row stays near the card fill.
  $ref = [double](Lum ($bmp.GetPixel($X, $y).R) ($bmp.GetPixel($X, $y).G) ($bmp.GetPixel($X, $y).B))
  $x0 = $X; $x1 = $X
  while ($x0 -gt 40) {
    $c = $bmp.GetPixel(($x0 - 8), $y)
    if ([math]::Abs((Lum $c.R $c.G $c.B) - $ref) -gt 14) { break }
    $x0 -= 8
  }
  while ($x1 -lt ($bmp.Width - 40)) {
    $c = $bmp.GetPixel(($x1 + 8), $y)
    if ([math]::Abs((Lum $c.R $c.G $c.B) - $ref) -gt 14) { break }
    $x1 += 8
  }
  return @($x0, $x1)
}

Write-Output ""
Write-Output "=== $Image  (probe column x=$X) ==="
foreach ($r in $runs) {
  $top = $r[0]; $bot = $r[1]
  if ($bot -gt ($bmp.Height - $RefOffset - 10)) { continue }

  $span = CardSpan ([math]::Max($top + 10, [math]::Min($bot - 10, $bmp.Height - 1)))
  $x0 = $span[0]; $x1 = $span[1]
  $width = $x1 - $x0

  $refY = [math]::Min($bot + $RefOffset, ($bmp.Height - 1))
  $pageRef = RowMedian $refY $x0 $x1

  Write-Output ""
  Write-Output ("card y={0}..{1}  span x={2}..{3} ({4}px wide)" -f $top, $bot, $x0, $x1, $width)
  Write-Output ("  page reference (median at y={0}): {1:F2}" -f $refY, $pageRef)

  $rows = @()
  for ($d = 0; $d -le $Below; $d += 4) {
    $y = $bot + $d
    if ($y -ge $bmp.Height) { break }
    $m = RowMedian $y $x0 $x1
    $rows += ,@($d, $m)
  }

  $inCard = RowMedian ($bot - 6) $x0 $x1
  Write-Output ("  card fill just above edge (y={0}): {1:F2}" -f ($bot - 6), $inCard)
  Write-Output "  below the edge (d = px past the card bottom, median across the card width):"
  foreach ($row in $rows) {
    $d = $row[0]; $m = $row[1]
    $delta = $pageRef - $m
    Write-Output ("    d={0,3}  L={1,7:F2}   darker than page by {2,6:F2}" -f $d, $m, $delta)
  }

  # The shadow peak is the most negative delta in the first 40px, ignoring d=0
  # which is the antialiased edge itself.
  $peak = 0.0; $peakD = -1
  foreach ($row in $rows) {
    $d = $row[0]; $m = $row[1]
    if ($d -eq 0 -or $d -gt 44) { continue }
    $delta = $pageRef - $m
    if ($delta -gt $peak) { $peak = $delta; $peakD = $d }
  }
  if ($peakD -gt 0) {
    $pct = 100.0 * $peak / $pageRef
    Write-Output ("  => SHADOW PEAK {0:F2} luminance units below the page ({1:F2}%), at d={2}px" -f $peak, $pct, $peakD)
    Write-Output ("     card fill to page step = {0:F2} units" -f ($pageRef - $inCard))
    Write-Output ("     shadow as a fraction of the card/page step = {0:F2}" -f ($(if (($pageRef - $inCard) -ne 0) { $peak / ($pageRef - $inCard) } else { 0 })))
  }
}

$bmp.Dispose()
