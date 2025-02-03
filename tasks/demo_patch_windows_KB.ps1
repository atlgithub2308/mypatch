param (
  [String]$kb_number
)

Write-Host "Checking if KB$kb_number is already installed..."

# Check if the KB is already installed
$kb_installed = Get-HotFix | Where-Object {$_.HotFixID -eq "KB$kb_number"}

if ($kb_installed) {
    Write-Host "KB$kb_number is already installed. No action needed."
    exit 0
}

Write-Host "KB$kb_number is missing. Proceeding with installation..."

# Download and install the KB update
$windows_update_url = "https://www.catalog.update.microsoft.com/Search.aspx?q=KB$kb_number"

Write-Host "Please download and install the update manually from: $windows_update_url"
Write-Host "Automated installation requires Windows Update or direct MSU file."

# Uncomment the below lines if you have the MSU file available for automation
# $msu_path = "C:\path\to\$kb_number.msu"
# Start-Process -FilePath "wusa.exe" -ArgumentList "$msu_path /quiet /norestart" -Wait

exit 0
