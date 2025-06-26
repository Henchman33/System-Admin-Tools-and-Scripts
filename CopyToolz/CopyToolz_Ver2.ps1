# =============================== MODULE LOADING ===============================
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Create paths
$basePath = Split-Path -Parent $MyInvocation.MyCommand.Definition
$configPath = Join-Path $basePath "config"
$logPath = Join-Path $basePath "logs"
$credFile = Join-Path $configPath "credentials.xml"

# Create folders if missing
@($configPath, $logPath) | ForEach-Object {
    if (-not (Test-Path $_)) { New-Item -Path $_ -ItemType Directory | Out-Null }
}

# =============================== FORM SETUP ===============================
$form = New-Object System.Windows.Forms.Form
$form.Text = "📁 Network Folder Copy Tool"
$form.Size = New-Object System.Drawing.Size(1024, 768)
$form.StartPosition = "CenterScreen"

function Add-Label {
    param ($text, $x, $y)
    $label = New-Object Windows.Forms.Label
    $label.Text = $text
    $label.Location = New-Object Drawing.Point($x, $y)
    $label.Size = New-Object Drawing.Size(150, 20)
    $form.Controls.Add($label)
    return $label
}

function Add-TextBox {
    param ($x, $y, $width = 370)
    $tb = New-Object Windows.Forms.TextBox
    $tb.Location = New-Object Drawing.Point($x, $y)
    $tb.Size = New-Object Drawing.Size($width, 20)
    $form.Controls.Add($tb)
    return $tb
}

# =============================== CONTROLS ===============================
Add-Label "Source Path or UNC:" 10 20
$textBoxSource = Add-TextBox 170 20

Add-Label "Destination Path or UNC:" 10 60
$textBoxDest = Add-TextBox 170 60

$chkUseCred = New-Object Windows.Forms.CheckBox
$chkUseCred.Text = "Use Network Credentials"
$chkUseCred.Location = New-Object Drawing.Point(170, 90)
$form.Controls.Add($chkUseCred)

$chkSaveCred = New-Object Windows.Forms.CheckBox
$chkSaveCred.Text = "Save Credentials"
$chkSaveCred.Location = New-Object Drawing.Point(330, 90)
$form.Controls.Add($chkSaveCred)

$chkDisconnect = New-Object Windows.Forms.CheckBox
$chkDisconnect.Text = "Disconnect Drives After Copy"
$chkDisconnect.Location = New-Object Drawing.Point(170, 115)
$form.Controls.Add($chkDisconnect)

$btnCred = New-Object Windows.Forms.Button
$btnCred.Text = "Set Credentials"
$btnCred.Location = New-Object Drawing.Point(500, 85)
$btnCred.Enabled = $false
$form.Controls.Add($btnCred)
$cred = $null
$btnCred.Add_Click({
    $cred = Get-Credential
    $btnCred.Text = "✔️ Set"
})

$chkUseCred.Add_CheckedChanged({
    $btnCred.Enabled = $chkUseCred.Checked
})

$logBox = New-Object Windows.Forms.TextBox
$logBox.Location = New-Object Drawing.Point(10, 190)
$logBox.Size = New-Object Drawing.Size(610, 250)
$logBox.Multiline = $true
$logBox.ScrollBars = "Vertical"
$logBox.ReadOnly = $true
$form.Controls.Add($logBox)

$progressBar = New-Object Windows.Forms.ProgressBar
$progressBar.Location = New-Object Drawing.Point(10, 460)
$progressBar.Size = New-Object Drawing.Size(610, 20)
$form.Controls.Add($progressBar)

$btnCopy = New-Object Windows.Forms.Button
$btnCopy.Text = "Start Copy"
$btnCopy.Location = New-Object Drawing.Point(270, 150)
$btnCopy.Size = New-Object Drawing.Size(100, 30)
$form.Controls.Add($btnCopy)

# =============================== COPY FUNCTION ===============================
$btnCopy.Add_Click({
    $source = $textBoxSource.Text.Trim()
    $destination = $textBoxDest.Text.Trim()
    $mounted = @()

    # Load saved credentials if enabled and file exists
    if ($chkUseCred.Checked -and -not $cred -and (Test-Path $credFile)) {
        try {
            $cred = Import-Clixml $credFile
        } catch {
            [System.Windows.Forms.MessageBox]::Show("Failed to load saved credentials. Please reset manually.")
            return
        }
    }

    # Map source
    if (-not (Test-Path $source)) {
        if ($chkUseCred.Checked -and $cred) {
            try {
                New-PSDrive -Name "Z" -PSProvider FileSystem -Root $source -Credential $cred -Persist -ErrorAction Stop | Out-Null
                $source = "Z:\"
                $mounted += "Z"
            } catch {
                [System.Windows.Forms.MessageBox]::Show("❌ Failed to map source drive.`n$($_.Exception.Message)")
                return
            }
        } else {
            [System.Windows.Forms.MessageBox]::Show("❌ Invalid source path.")
            return
        }
    }

    # Map destination
    if (-not (Test-Path $destination)) {
        if ($chkUseCred.Checked -and $cred) {
            try {
                New-PSDrive -Name "Y" -PSProvider FileSystem -Root $destination -Credential $cred -Persist -ErrorAction Stop | Out-Null
                $destination = "Y:\"
                $mounted += "Y"
            } catch {
                [System.Windows.Forms.MessageBox]::Show("❌ Failed to map destination drive.`n$($_.Exception.Message)")
                return
            }
        } else {
            New-Item -ItemType Directory -Path $destination -Force | Out-Null
        }
    }

    # Save credentials if requested
    if ($chkUseCred.Checked -and $chkSaveCred.Checked -and $cred) {
        $cred | Export-Clixml -Path $credFile
    }

    # Start Copy
    $logFile = Join-Path $logPath ("CopyLog_" + (Get-Date -Format "yyyyMMdd_HHmmss") + ".log")
    $files = Get-ChildItem -Path $source -Recurse -File
    $total = $files.Count
    $counter = 0
    $logBox.Clear()

    foreach ($file in $files) {
        $relative = $file.FullName.Substring($source.Length)
        $destPath = Join-Path $destination $relative
        $destDir = Split-Path $destPath
        if (-not (Test-Path $destDir)) {
            New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        }

        try {
            Copy-Item -Path $file.FullName -Destination $destPath -Force
            $logBox.AppendText("Copied: $relative`r`n")
            Add-Content $logFile "[$(Get-Date -Format "HH:mm:ss")] Copied: $relative"
        } catch {
            $logBox.AppendText("ERROR copying ${relative}: $($_.Exception.Message)`r`n")
            Add-Content $logFile "[$(Get-Date -Format "HH:mm:ss")] ERROR: ${relative}: $($_.Exception.Message)"
        }

        $counter++
        $progressBar.Value = [math]::Min(100, [math]::Round(($counter / $total) * 100))
    }

    # Disconnect drives
    if ($chkDisconnect.Checked -and $mounted.Count -gt 0) {
        foreach ($d in $mounted) {
            Remove-PSDrive -Name $d -Force -ErrorAction SilentlyContinue
        }
    }

    [System.Windows.Forms.MessageBox]::Show("✅ Copy complete! Log saved at:`n$logFile")
})

# =============================== LAUNCH FORM ===============================
[void]$form.ShowDialog()
