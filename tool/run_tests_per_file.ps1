# Runs the Dart suite one file at a time, the way dart_test.yaml's comment
# requires on this low-RAM machine: a single full run does not complete, and the
# file that dies moves between runs, so "the suite passed" is only a claim that
# can be made from per-file results.
#
# Files run in batches so peak memory stays bounded; a batch is just a
# checkpoint in the same sequential run.
#
# Usage (PowerShell): .\tool\run_tests_per_file.ps1 [-Retries 2] [-BatchSize 5]
param([int]$Retries = 2, [int]$BatchSize = 5)
if ($BatchSize -lt 1) { $BatchSize = 1 }

# Only *_test.dart. widget_text_helpers.dart is a helper with no test
# declarations, so the filter already excludes it.
$files = Get-ChildItem test -Filter *_test.dart -File | Sort-Object Name
$total = 0
$results = @()

for ($i = 0; $i -lt $files.Count; $i += $BatchSize) {
  $end = [Math]::Min($i + $BatchSize - 1, $files.Count - 1)
  Write-Host ("batch {0}/{1}  files {2}-{3}" -f `
    ([Math]::Floor($i / $BatchSize) + 1), `
    [Math]::Ceiling($files.Count / $BatchSize), ($i + 1), ($end + 1)) -ForegroundColor Cyan

  foreach ($f in $files[$i..$end]) {
    $ok = $false
    $status = 'FAIL'
    $n = 0
    for ($attempt = 1; $attempt -le ($Retries + 1) -and -not $ok; $attempt++) {
      $out = flutter test $f.FullName --reporter compact 2>&1 | Out-String
      if ($out -match 'All tests passed') {
        $ok = $true
        $status = 'PASS'
        $n = [int]([regex]::Match($out, '\+(\d+): All tests passed').Groups[1].Value)
        $total += $n
        Write-Host ("PASS  {0,-52} {1,4}" -f $f.Name, $n)
      }
      elseif ($attempt -eq ($Retries + 1)) {
        # Name the cause, because "FAIL" alone is ambiguous: the OOM
        # artifacts in dart_test.yaml are not assertion failures.
        $oom = $out -match 'did not complete' -or $out -match "loading .*_test\.dart"
        if ($oom) {
          $status = 'FAIL [OOM]'
          Write-Host ("FAIL  {0,-52} attempts {1}  [OOM: isolate killed, not an assertion]" -f `
            $f.Name, $attempt) -ForegroundColor Yellow
        }
        else {
          $status = 'FAIL [assertion]'
          Write-Host ("FAIL  {0,-52} attempts {1}  [assertion]" -f `
            $f.Name, $attempt) -ForegroundColor Red
        }
      }
      else {
        Start-Sleep -Seconds 3
      }
    }
    $results += [pscustomobject]@{ Name = $f.Name; Status = $status; Tests = $n }
  }
}

$failed = @($results | Where-Object { $_.Status -ne 'PASS' })

Write-Host ""
Write-Host "---- result table ----"
$results | ForEach-Object {
  $color = if ($_.Status -eq 'PASS') { 'Green' } else { 'Red' }
  Write-Host ("{0,-16} {1,-52} {2,4}" -f $_.Status, $_.Name, $_.Tests) -ForegroundColor $color
}

Write-Host ""
Write-Host ("files: {0}  tests passed: {1}  files failing after retries: {2}" -f `
  $files.Count, $total, $failed.Count)
if ($failed.Count -gt 0) {
  Write-Host ($failed.Name -join "`n") -ForegroundColor Red
  exit 1
}
exit 0
