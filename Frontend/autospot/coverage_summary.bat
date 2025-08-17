@echo off
echo ========================================
echo       Flutter Coverage Summary
echo ========================================
echo.

REM Run tests with coverage
echo Running tests with coverage...
flutter test --coverage

REM Parse the lcov.info file to show summary
echo.
echo Coverage Summary:
echo ----------------------------------------

REM Count total lines and covered lines
powershell -Command "$content = Get-Content coverage/lcov.info; $totalLines = 0; $coveredLines = 0; $files = @{}; $currentFile = ''; foreach($line in $content) { if($line -match '^SF:(.*)') { $currentFile = $matches[1] -replace '\\', '/'; $files[$currentFile] = @{total=0; covered=0} } elseif($line -match '^DA:(\d+),(\d+)') { $files[$currentFile].total++; if([int]$matches[2] -gt 0) { $files[$currentFile].covered++ } } }; foreach($file in $files.Keys | Sort-Object) { $coverage = if($files[$file].total -gt 0) { [math]::Round(($files[$file].covered / $files[$file].total) * 100, 1) } else { 0 }; if($file -match 'lib/(user|operator)/.*\.dart$') { Write-Host ('{0,-60} {1,5:N1}% ({2}/{3})' -f [System.IO.Path]::GetFileName($file), $coverage, $files[$file].covered, $files[$file].total) } }; $totalLines = ($files.Values | Measure-Object -Property total -Sum).Sum; $coveredLines = ($files.Values | Measure-Object -Property covered -Sum).Sum; $overallCoverage = if($totalLines -gt 0) { [math]::Round(($coveredLines / $totalLines) * 100, 1) } else { 0 }; Write-Host ''; Write-Host ('Overall Coverage: {0:N1}% ({1}/{2} lines)' -f $overallCoverage, $coveredLines, $totalLines)"

echo.
echo ========================================
pause