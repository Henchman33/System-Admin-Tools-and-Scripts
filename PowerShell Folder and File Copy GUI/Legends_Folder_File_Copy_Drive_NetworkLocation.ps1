# ===================== CONFIGURATION =====================
$sourceDrive = "G:\"         # Change to your source folder
$destinationDrive = "F:\SSDS BACK UP"  # Change to your destination folder
$logFile = "C:\Logs\FileCopyLog_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

# ===================== PREPARE =====================
# Create destination folder if it doesn't exist
if (-not (Test-Path $destinationDrive)) {
    New-Item -ItemType Directory -Path $destinationDrive -Force | Out-Null
}

# Create log directory if it doesn't exist
$logDir = Split-Path $logFile
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

# Get list of all files to copy
$files = Get-ChildItem -Path $sourceDrive -Recurse -File
$total = $files.Count
$counter = 0

# ===================== COPY LOOP =====================
Write-Host "Copying $total files..." -ForegroundColor Cyan
Add-Content -Path $logFile -Value "=== File Copy Log Started: $(Get-Date) ===`n"

foreach ($file in $files) {
    $relativePath = $file.FullName.Substring($sourceDrive.Length)
    $destinationPath = Join-Path $destinationDrive $relativePath

    # Create destination subdirectory if needed
    $destDir = Split-Path $destinationPath
    if (-not (Test-Path $destDir)) {
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    }

    try {
        Copy-Item -Path $file.FullName -Destination $destinationPath -Force

        # Log success
        Add-Content -Path $logFile -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Copied: $relativePath"
    }
    catch {
        # Log error — using ${} for proper variable parsing
        Add-Content -Path $logFile -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] ERROR copying ${relativePath}: $($_.Exception.Message)"
    }

    # Update progress bar
    $counter++
    $percent = [math]::Round(($counter / $total) * 100, 2)
    Write-Progress -Activity "Copying files..." -Status "$counter of $total ($percent%)" -PercentComplete $percent
}

# ===================== DONE =====================
Write-Host "`n✅ Copy operation completed. Log saved to: $logFile" -ForegroundColor Green
Add-Content -Path $logFile -Value "`n=== File Copy Completed: $(Get-Date) ==="
