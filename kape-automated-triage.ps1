# ================================
# Remote KAPE Execution Script
# ================================

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


# --- Test Connections ---
Write-Host "Testing Connections to SFTP Server and Remote Host....."

if (Test-Connection -ComputerName $sftpserver -Count 2 -Quiet) {
    Write-Host "Connection to SFTP Server established!" -ForegroundColor Green
} else {
    Write-Host "SFTP Server is not reachable... EXITING" -ForegroundColor Red
    exit
}

if (Test-Connection -ComputerName $remoteHost -Count 2 -Quiet) {
    Write-Host "Connection to $remoteHost has been established!`nBeginning Triage!" -ForegroundColor Green
} else {
    Write-Host "$remoteHost is NOT reachable.... EXITING" -ForegroundColor Red
    exit
}


# --- Validate PsExec and Local KAPE Folder ---
Write-Host "Checking for PsExec..."
if (-not (Test-Path -Path $psexecPath)) {
    Write-Host "PsExec not found at $psexecPath. Please install or move it to that location." -ForegroundColor Red
    exit
} else {
    Write-Host "PsExec Installed!" -ForegroundColor Green
}

Write-Host "Checking local KAPE folder..."
if (-not (Test-Path -Path $kapeZip )) {
    Write-Host "KAPE ZIP not found at $kapeZip. Please install or move it to that location." -ForegroundColor Red
    exit
} else {
    Write-Host "KAPE ZIP found locally!" -ForegroundColor Green
}


# --- Deploy KAPE to Remote Host if Not Present ---
Write-Host "Checking if KAPE exists on $remoteHost..."
$remoteKapeCheck = (Test-Path "\\$remoteHost\c$\kape.zip") -or (Test-Path "\\$remoteHost\c$\kape")

if (-not $remoteKapeCheck) {
    Write-Host "KAPE not found on remote host. Copying files..." -ForegroundColor Yellow
    Copy-Item -Path $kapeZip -Destination "\\$remoteHost\c$\" -Force
} else {
    Write-Host "KAPE folder already exists on remote host. Skipping copy." -ForegroundColor Green
}


# --- Step 1: Expand KAPE ZIP Archive on Remote Host ---
Write-Host "`n[1/2] Expanding KAPE.zip on $remoteHost..." -ForegroundColor Yellow

$expandCmd = "powershell -NoProfile -ExecutionPolicy Bypass -Command `"Expand-Archive -Force -Path '$kapeRemoteZip' -DestinationPath 'C:\'`""
$expandArgs = "cmd /c `"$expandCmd`""
$expandPsExecArgs = "\\$remoteHost -accepteula -s $expandArgs"

Start-Process -FilePath $psexecPath -ArgumentList $expandPsExecArgs -Wait -NoNewWindow


# --- Step 2: Run KAPE on Remote Host ---
Write-Host "`n[2/2] Running KAPE on $remoteHost..." -ForegroundColor Yellow

$kapeArgs = "$kapeRemotePath\kape.exe --tsource c:\ --tdest C:\Kape\tout --tflush --target Prefetch -vss --scs 192.168.70.23 --scp 22 --scu $sftpuser --scpw `"$sftpass`" --scd $sftpoutdir --vhdx $remoteHost --mdest C:\Kape\mout --mflush --zm true --module PEcmd"
$cmdArgs = "cmd /c `"$kapeArgs`""
$psexecArgs = "\\$remoteHost -accepteula -s $cmdArgs"

Start-Process -FilePath $psexecPath -ArgumentList $psexecArgs -Wait -NoNewWindow

Start-Sleep -Seconds 5  # Brief pause before cleanup


# --- Cleanup KAPE Files on Remote Host ---
Write-Host "Cleaning up files on target......" -ForegroundColor Yellow

# Remove KAPE folder
try {
    if (Test-Path "\\$remoteHost\c$\Kape") {
        Remove-Item "\\$remoteHost\c$\Kape" -Recurse -Force -Confirm:$false
        Write-Host "Removed KAPE folder: \\$remoteHost\c$\Kape" -ForegroundColor Green
    } else {
        Write-Host "KAPE folder not found: \\$remoteHost\c$\Kape"
    }
} catch {
    Write-Warning "Failed to remove KAPE folder: $($_.Exception.Message)"
}

# Remove KAPE zip file
try {
    if (Test-Path "\\$remoteHost\c$\Kape.zip") {
        Remove-Item "\\$remoteHost\c$\Kape.zip" -Force -Confirm:$false
        Write-Host "Removed KAPE zip file: \\$remoteHost\c$\Kape.zip" -ForegroundColor Green
    } else {
        Write-Host "KAPE zip file not found: \\$remoteHost\c$\Kape.zip"
    }
} catch {
    Write-Warning "Failed to remove KAPE zip file: $($_.Exception.Message)"
}

# Verify Cleanup
if (-not (Test-Path "\\$remoteHost\c$\Kape") -and -not (Test-Path "\\$remoteHost\c$\Kape.zip")) {
    Write-Host "`nCleanup complete: KAPE files removed from target.`n" -ForegroundColor Green
} else {
    Write-Host "`nERROR: KAPE files may still be present on remote host.`n" -ForegroundColor Red
}


# --- Done ---
Write-Host "`nKAPE execution complete! Output is available in $sftpoutdir on SFTP Server" -ForegroundColor Green