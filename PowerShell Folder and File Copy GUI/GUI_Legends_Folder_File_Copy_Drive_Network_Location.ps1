Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ===================== FORM SETUP =====================
$form = New-Object System.Windows.Forms.Form
$form.Text = "Legend's PowerShell Folder Copy Tool"
$form.Size = New-Object System.Drawing.Size(800, 600)
$form.StartPosition = "CenterScreen"

# ===================== LABELS =====================
$labelSource = New-Object System.Windows.Forms.Label
$labelSource.Text = "Source Folder:"
$labelSource.Location = New-Object System.Drawing.Point(10, 20)
$labelSource.Size = New-Object System.Drawing.Size(100, 20)
$form.Controls.Add($labelSource)

$labelDest = New-Object System.Windows.Forms.Label
$labelDest.Text = "Destination Folder:"
$labelDest.Location = New-Object System.Drawing.Point(10, 60)
$labelDest.Size = New-Object System.Drawing.Size(120, 20)
$form.Controls.Add($labelDest)

# ===================== TEXT BOXES =====================
$textBoxSource = New-Object System.Windows.Forms.TextBox
$textBoxSource.Location = New-Object System.Drawing.Point(140, 20)
$textBoxSource.Size = New-Object System.Drawing.Size(340, 20)
$form.Controls.Add($textBoxSource)

$textBoxDest = New-Object System.Windows.Forms.TextBox
$textBoxDest.Location = New-Object System.Drawing.Point(140, 60)
$textBoxDest.Size = New-Object System.Drawing.Size(340, 20)
$form.Controls.Add($textBoxDest)

# ===================== BROWSE BUTTONS =====================
$btnBrowseSource = New-Object System.Windows.Forms.Button
$btnBrowseSource.Text = "Browse"
$btnBrowseSource.Location = New-Object System.Drawing.Point(490, 18)
$btnBrowseSource.Add_Click({
    $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
    if ($folderBrowser.ShowDialog() -eq "OK") {
        $textBoxSource.Text = $folderBrowser.SelectedPath
    }
})
$form.Controls.Add($btnBrowseSource)

$btnBrowseDest = New-Object System.Windows.Forms.Button
$btnBrowseDest.Text = "Browse"
$btnBrowseDest.Location = New-Object System.Drawing.Point(490, 58)
$btnBrowseDest.Add_Click({
    $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
    if ($folderBrowser.ShowDialog() -eq "OK") {
        $textBoxDest.Text = $folderBrowser.SelectedPath
    }
})
$form.Controls.Add($btnBrowseDest)

# ===================== LOG OUTPUT =====================
$logBox = New-Object System.Windows.Forms.TextBox
$logBox.Location = New-Object System.Drawing.Point(10, 140)
$logBox.Size = New-Object System.Drawing.Size(560, 180)
$logBox.Multiline = $true
$logBox.ScrollBars = "Vertical"
$logBox.ReadOnly = $true
$form.Controls.Add($logBox)

# ===================== PROGRESS BAR =====================
$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Location = New-Object System.Drawing.Point(10, 330)
$progressBar.Size = New-Object System.Drawing.Size(560, 20)
$form.Controls.Add($progressBar)

# ===================== COPY BUTTON =====================
$btnCopy = New-Object System.Windows.Forms.Button
$btnCopy.Text = "Start Copy"
$btnCopy.Location = New-Object System.Drawing.Point(240, 100)
$btnCopy.Size = New-Object System.Drawing.Size(100, 30)
$btnCopy.Add_Click({
    $source = $textBoxSource.Text
    $destination = $textBoxDest.Text

    if (-not (Test-Path $source)) {
        [System.Windows.Forms.MessageBox]::Show("Source path is invalid.")
        return
    }

    if (-not (Test-Path $destination)) {
        New-Item -ItemType Directory -Path $destination -Force | Out-Null
    }

    $logBox.Clear()
    $files = Get-ChildItem -Path $source -Recurse -File
    $total = $files.Count
    $counter = 0

    foreach ($file in $files) {
        $relativePath = $file.FullName.Substring($source.Length)
        $destPath = Join-Path $destination $relativePath
        $destDir = Split-Path $destPath

        if (-not (Test-Path $destDir)) {
            New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        }

        try {
            Copy-Item -Path $file.FullName -Destination $destPath -Force
            $logBox.AppendText("Copied: $relativePath`r`n")
        }
        catch {
            $logBox.AppendText("ERROR copying ${relativePath}: $($_.Exception.Message)`r`n")

        }

        $counter++
        $progressBar.Value = [math]::Min(100, [math]::Round(($counter / $total) * 100))
    }

    [System.Windows.Forms.MessageBox]::Show("✅ Copy operation completed!")
})
$form.Controls.Add($btnCopy)

# ===================== RUN =====================
[void]$form.ShowDialog()
