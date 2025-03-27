# Kape-Automated-Triage  
## 🔍 PowerShell DFIR Triage Script with KAPE

**PowerShell script for performing DFIR triage on remote systems quickly.**  
The script is designed so the analyst can efficiently triage a system without the typical overhead KAPE requires — such as manual setup, file transfers, and cleanup.

---

## ⚙️ What This Script Does

This script automates the following:

1. Prompts the analyst for a remote host  
2. Tests connectivity to both the SFTP server and the remote system  
3. Verifies required tools are available locally (KAPE and PsExec)  
4. Copies `kape.zip` to the remote host if it's not already present  
5. Remotely unpacks KAPE using PowerShell via PsExec  
6. Executes a predefined KAPE collection and module triage  
7. Automatically uploads results to an SFTP server  
8. Cleans up KAPE files from the remote host after execution  

---

## 📝 Requirements

> 💡 *Note: I am using PsExec as the default method since it’s the standard in my company. The script can also be adapted to use PowerShell Remoting, but would require minor adjustments.*

- **PsExec** installed at: `C:\sysinternalssuite\PsExec.exe`
- A **KAPE zip package** (`kape.zip`) containing:
  - A minimal KAPE folder with:
    - `KapeTriage` target  
    - `!EZParser` module  
  - In my experience, this setup provides everything needed for initial forensic triage.
- **KAPE zip folder** should be hosted:
  - Locally on your machine  
  **OR**
  - On a file server accessible via `\\HOST\c$` (SMB)
- Analyst and target systems must allow:
  - Admin access via SMB (`\\HOST\c$`)  
  - Remote execution permissions
- An **SFTP server** accessible from the target host for output delivery

---

## 🔧 Configuration Notes

Before running the script:

### 1. Set the `$kapezip` variable  
Change it to reflect the path to your `kape.zip`.

- Example (local):  
  `C:\IR\KAPE\kape.zip`

- Example (hosted on server):  
  `\\host\c$\path\to\kape.zip`

---

### 2. Update SFTP credentials  
Modify the following variables in the script to match your SFTP environment:

```powershell
$sftpserver = "your-sftp-server"
$sftpuser   = "your-username"
$sftpass    = "your-password"  # or use Get-Credential if you don't want to hardcode it
$sftpoutdir = "your output directory on the SFTP server"
'''



### 3. TEst
