# PowerShell script to check actual test coverage

Write-Host "Checking actual test coverage..." -ForegroundColor Green

# Count total Dart files in lib directory
$totalFiles = (Get-ChildItem -Path "lib" -Recurse -Filter "*.dart" | Measure-Object).Count
Write-Host "Total Dart files in lib: $totalFiles" -ForegroundColor Yellow

# Count files mentioned in coverage report
if (Test-Path "coverage\lcov.info") {
    $coveredFiles = (Select-String -Path "coverage\lcov.info" -Pattern "^SF:" | Measure-Object).Count
    Write-Host "Files in coverage report: $coveredFiles" -ForegroundColor Cyan
    
    # Calculate actual coverage percentage
    $actualCoverage = [math]::Round(($coveredFiles / $totalFiles) * 100, 2)
    Write-Host "Actual file coverage: $actualCoverage%" -ForegroundColor Magenta
    
    # List uncovered files
    Write-Host "`nUncovered files:" -ForegroundColor Red
    $coveredFilesList = Select-String -Path "coverage\lcov.info" -Pattern "^SF:lib/(.*)" | ForEach-Object { $_.Matches[0].Groups[1].Value }
    
    Get-ChildItem -Path "lib" -Recurse -Filter "*.dart" | ForEach-Object {
        $relativePath = $_.FullName.Substring($_.FullName.IndexOf("lib\") + 4).Replace("\", "/")
        if ($coveredFilesList -notcontains $relativePath) {
            Write-Host "  - $relativePath" -ForegroundColor Red
        }
    }
} else {
    Write-Host "Coverage report not found. Run 'flutter test --coverage' first." -ForegroundColor Red
}