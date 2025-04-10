# ============================
# Load GUI Libraries
# ============================
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
 


# --- Define Variables ---
$remoteHost = Read-Host "Please enter the Remote Host"

$kapeZip        = "<Your Kape ZIP location>"
$kapeRemotePath       = "C:\KAPE"
$kapeRemoteZip        = "C:\kape.zip"
$psexecPath           = "C:\sysinternalssuite\PsExec.exe"

$sftpserver = "your-sftp-server"
$sftpuser   = "your-username"
$sftpass    = "your-password"  # or use Get-Credential if you don't want to hardcode it
$sftpoutdir = "your output directory on the SFTP server"


# ============================
# Functions
# ============================

function Test-Connections {
    param(
        [string]$remoteHost,
        [string]$sftpserver
    )
	
	Write-Host "Checking Connections...." -ForegroundColor Yellow

    if (-not (Test-Connection -ComputerName $remoteHost -Count 2 -Quiet)) {
        [System.Windows.Forms.MessageBox]::Show("Remote host $remoteHost is NOT reachable. Exiting...")
        throw "Remote host unreachable"   # <-- throw a terminating error
    }
    Write-Host "Connection to $remoteHost established." -ForegroundColor Green

    if (-not (Test-Connection -ComputerName $sftpserver -Count 2 -Quiet)) {
        [System.Windows.Forms.MessageBox]::Show("SFTP server $sftpserver is NOT reachable. Exiting...")
        throw "SFTP server unreachable"    # <-- throw a terminating error
    }
    Write-Host "Connection to SFTP Server $sftpserver established." -ForegroundColor Green
}

function KapeTriage {
    param(
        [string]$remoteHost
    )

    Write-Host "Starting KAPE triage on $remoteHost..."

    # --- Copy KAPE ZIP ---
    try {
        if (-not (Test-Path "\\$remoteHost\c$\KAPE") -and -not (Test-Path "\\$remoteHost\c$\kape.zip")) {
            Copy-Item -Path $kapeZip -Destination "\\$remoteHost\c$\" -Force -ErrorAction Stop
            Write-Host "KAPE zip copied to $remoteHost." -ForegroundColor Green
        } else {
            Write-Host "KAPE already exists on $remoteHost, skipping copy." -ForegroundColor Green
        }
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Failed to copy KAPE: $($_.Exception.Message)")
        return
    }

    # --- Expand KAPE ZIP ---
    try {
        $expandCmd = "powershell -NoProfile -ExecutionPolicy Bypass -Command `"Expand-Archive -Force -Path '$kapeRemoteZip' -DestinationPath 'C:\'`""
        Start-Process -FilePath $psexecPath -ArgumentList "\\$remoteHost -accepteula -s cmd /c `"$expandCmd`"" -Wait -NoNewWindow -ErrorAction Stop
        Write-Host "KAPE archive expanded on $remoteHost."
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Failed to expand KAPE archive: $($_.Exception.Message)")
        return
    }

    # --- Run KAPE ---
    try {
        $kapeArgs = "$kapeRemotePath\kape.exe --tsource c:\ --tdest C:\Kape\tout --tflush --target KapeTriage -vss --scs $sftpserver --scp 22 --scu $sftpuser --scpw `"$sftpass`" --scd $sftpoutdir --vhdx %d --mdest C:\Kape\mout --mflush --zm true --module !EZParser,Persistence,LiveResponse_NetworkDetails,LiveResponse_ProcessDetails "
        Start-Process -FilePath $psexecPath -ArgumentList "\\$remoteHost -accepteula -s cmd /c `"$kapeArgs`"" -Wait -NoNewWindow -ErrorAction Stop
        Write-Host "KAPE executed successfully on $remoteHost, output available on $sftpserver. Remember to cleanup before exiting" -ForegroundColor Green
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Failed to execute KAPE: $($_.Exception.Message)")
        return
    }
}

function Collect-MemoryDump {
	param(
        [string]$remoteHost
    )
	
	
	Write-Host "Starting memory dump on $remoteHost..."
  try {
        if (-not (Test-Path "\\$remoteHost\c$\KAPE") -and -not (Test-Path "\\$remoteHost\c$\kape.zip")) {
            Copy-Item -Path $kapeZip -Destination "\\$remoteHost\c$\" -Force -ErrorAction Stop
            Write-Host "KAPE zip copied to $remoteHost." -ForegroundColor Green
        } else {
            Write-Host "KAPE already exists on $remoteHost, skipping copy." -ForegroundColor Green
        }
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Failed to copy KAPE: $($_.Exception.Message)")
        return
    }

    # --- Expand KAPE ZIP ---
    try {
        $expandCmd = "powershell -NoProfile -ExecutionPolicy Bypass -Command `"Expand-Archive -Force -Path '$kapeRemoteZip' -DestinationPath 'C:\'`""
        Start-Process -FilePath $psexecPath -ArgumentList "\\$remoteHost -accepteula -s cmd /c `"$expandCmd`"" -Wait -NoNewWindow -ErrorAction Stop
        Write-Host "KAPE archive expanded on $remoteHost."
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Failed to expand KAPE archive: $($_.Exception.Message)")
        return
    }

          try {
        $kapeArgs = "$kapeRemotePath\kape.exe --tsource c:\ --tdest C:\Kape\tout --tflush --target MemoryFiles -vss --scs $sftpserver --scp 22 --scu $sftpuser --scpw `"$sftpass`" --scd $sftpmem --vhdx $remoteHost --mdest C:\Kape\mout --mflush --zm true --module DumpIt_Memory"
        Start-Process -FilePath $psexecPath -ArgumentList "\\$remoteHost -accepteula -s cmd /c `"$kapeArgs`"" -Wait -NoNewWindow -ErrorAction Stop
        Write-Host "KAPE executed successfully on $remoteHost, output available on $sftpserver. Remember to cleanup before exiting" -ForegroundColor Green
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Failed to execute KAPE: $($_.Exception.Message)")
        return
    }
}


function Cleanup-RemoteHost {
    param(
        [string]$remoteHost
    )

    Write-Host "Starting cleanup on $remoteHost..." -ForegroundColor Yellow

    try {
        if (Test-Path "\\$remoteHost\c$\KAPE") {
            Remove-Item "\\$remoteHost\c$\KAPE" -Recurse -Force -ErrorAction Stop
            Write-Host "Removed KAPE folder." -ForegroundColor Green
        }
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Failed to remove KAPE folder: $($_.Exception.Message)")
    }

    try {
        if (Test-Path "\\$remoteHost\c$\kape.zip") {
            Remove-Item "\\$remoteHost\c$\kape.zip" -Force -ErrorAction Stop
            Write-Host "Removed KAPE zip." -ForegroundColor Green
        }
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Failed to remove KAPE zip: $($_.Exception.Message)")
    }

    Write-Host "Cleanup completed on $remoteHost." -ForegroundColor Green
}

 function Exit-Application {
    Write-Host "Exiting application..."
    if ($form) { $form.Close() }
}



# ============================
# GUI Setup
# ============================

$form = New-Object System.Windows.Forms.Form
$form.Text = "Remote IR Tool"
$form.Size = New-Object System.Drawing.Size(400,400)
$form.StartPosition = "CenterScreen"

# --- Remote Host Label ---
$hostLabel = New-Object System.Windows.Forms.Label
$hostLabel.Location = New-Object System.Drawing.Point(10,20)
$hostLabel.Size = New-Object System.Drawing.Size(100,20)
$hostLabel.Text = "Remote Host:"
$form.Controls.Add($hostLabel)

# --- Remote Host Input ---
$hostInput = New-Object System.Windows.Forms.TextBox
$hostInput.Location = New-Object System.Drawing.Point(120,18)
$hostInput.Size = New-Object System.Drawing.Size(200,20)
$form.Controls.Add($hostInput)

# --- Deploy Button ---
$deployButton = New-Object System.Windows.Forms.Button
$deployButton.Location = New-Object System.Drawing.Point(10,60)
$deployButton.Size = New-Object System.Drawing.Size(150,40)
$deployButton.Text = "Run KAPE Triage"
$deployButton.Add_Click({
    $remoteHost = $hostInput.Text.Trim()

    if ($remoteHost) {
        try {
         
            Test-Connections -remoteHost $remoteHost -sftpserver $sftpserver

            # If we get here, connections passed
            KapeTriage $remoteHost
        } catch {
            
          Write-Host "`n===================================================" -ForegroundColor DarkGray
		  Write-Host "[!] Connection failed. Please ensure the remote host and SFTP server are online." -ForegroundColor Red
	      Write-Host "===================================================" -ForegroundColor DarkGray

            
        }
    } else {
        [System.Windows.Forms.MessageBox]::Show("Please enter a remote host!")
    }
})


$form.Controls.Add($deployButton)

# --- Memory Dump Button ---
$memdumpButton = New-Object System.Windows.Forms.Button
$memdumpButton.Location = New-Object System.Drawing.Point(200,60)
$memdumpButton.Size = New-Object System.Drawing.Size(150,40)
$memdumpButton.Text = "Collect Memory Dump"
$memdumpButton.Add_Click({
    $remoteHost = $hostInput.Text.Trim()

    if ($remoteHost) {
        Collect-MemoryDump $remoteHost
    } else {
        [System.Windows.Forms.MessageBox]::Show("Please enter a remote host!")
    }
})
$form.Controls.Add($memdumpButton)

# --- Cleanup Button ---
$cleanupButton = New-Object System.Windows.Forms.Button
$cleanupButton.Location = New-Object System.Drawing.Point(100,120)
$cleanupButton.Size = New-Object System.Drawing.Size(150,40)
$cleanupButton.Text = "Cleanup Remote Host"
$cleanupButton.Add_Click({
    $remoteHost = $hostInput.Text.Trim()

    if ($remoteHost) {
        Cleanup-RemoteHost $remoteHost
    } else {
        [System.Windows.Forms.MessageBox]::Show("Please enter a remote host!")
    }
})
$form.Controls.Add($cleanupButton)

# --- Exit Button ---
$exitButton = New-Object System.Windows.Forms.Button
$exitButton.Location = New-Object System.Drawing.Point(100,180)
$exitButton.Size = New-Object System.Drawing.Size(150,40)
$exitButton.Text = "Exit"
$exitButton.Add_Click({
    Exit-Application
})
$form.Controls.Add($exitButton)

# ============================
# Show the Form
# ============================
$form.Topmost = $true
$form.Add_Shown({$form.Activate()})
[void]$form.ShowDialog()
