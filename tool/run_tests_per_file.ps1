# Runs the Dart suite one file at a time, the way dart_test.yaml's comment
# requires on this 7 GB machine: a single full run does not complete, and the
# file that dies moves between runs, so "the suite passed" is only a claim that
# can be made from per-file results.
#
# Usage (PowerShell): .\tool\run_tests_per_file.ps1 [-Retries 2]
param([int]$Retries = 2)

$files = Get-ChildItem test -Filter *_test.dart | Sort-Object Name
$total = 0
$failed = @()

foreach ($f in $files) {
  $ok = $false
  for ($attempt = 1; $attempt -le ($Retries + 1) -and -not $ok; $attempt++) {
    $out = flutter test $f.FullName --reporter compact 2>&1 | Out-String
    if ($out -match 'All tests passed') {
      $ok = $true
      $n = [int]([regex]::Match($out, '\+(\d+): All tests passed').Groups[1].Value)
      $total += $n
      Write-Host ("PASS  {0,-52} {1,4}" -f $f.Name, $n)
    }
    elseif ($attempt -eq ($Retries + 1)) {
      $failed += $f.Name
      Write-Host ("FAIL  {0,-52} attempts {1}" -f $f.Name, $attempt) -ForegroundColor Red
    }
    else {
      Start-Sleep -Seconds 3
    }
  }
}

Write-Host ""
Write-Host ("files: {0}  tests passed: {1}  files failing after retries: {2}" -f `
  $files.Count, $total, $failed.Count)
if ($failed.Count -gt 0) { Write-Host ($failed -join "`n") -ForegroundColor Red }
if ($failed.Count -gt 0) { exit 1 }