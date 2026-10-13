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
      # **Name the cause, because "FAIL" on its own is ambiguous.**
      #
      # `dart_test.yaml`'s comment describes two symptoms of the same thing: the
      # whole rest of a file reported as "did not complete", and a bare
      # "loading <file>.dart" failure. Neither is an assertion failure, and
      # treating them as one is how a machine problem gets reported as a bug -
      # which is what happened here three times before anyone checked.
      #
      # An assertion failure carries the test's own `reason` string, which is
      # what makes it useful. This branch is reached only when the run failed
      # three times, so the distinction at this point is the difference between
      # "fix the code" and "the file is too big for 7 GB".
      $oom = $out -match 'did not complete' -or $out -match "loading .*_test\.dart"
      if ($oom) {
        Write-Host ("FAIL  {0,-52} attempts {1}  [OOM: isolate killed, not an assertion]" -f `
          $f.Name, $attempt) -ForegroundColor Yellow
      }
      else {
        Write-Host ("FAIL  {0,-52} attempts {1}  [assertion]" -f `
          $f.Name, $attempt) -ForegroundColor Red
      }
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