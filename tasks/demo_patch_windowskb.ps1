param (
  [String]$kb_number
)

Write-Host "Checking if KB $kb_number is installed..."

# Get the list of installed updates
$installed_updates = Get-HotFix | Where-Object { $_.Description -eq "Update" }

# Check if the given KB number is installed
$kb_installed = $installed_updates | Where-Object { $_.HotFixID -eq "KB$kb_number" }

if ($kb_installed) {
    Write-Host "KB$kb_number is already installed."
    exit 0
} else {
    Write-Host "KB$kb_number is not installed. Attempting to install..."

    # Install the KB update
    $update_url = "http://download.windowsupdate.com/d/msdownload/update/driver/drvs/2021/08/windows10.0-kb$kb_number-x64_1234567890.msu"  # Example URL, please replace with actual KB URL
    $msu_file = "C:\Windows\Temp\KB$kb_number.msu"

    Invoke-WebRequest -Uri $update_url -OutFile $msu_file

    # Install the update
    Start-Process -FilePath "wusa.exe" -ArgumentList "$msu_file /quiet /norestart" -Wait

    # Check the exit code of the update installation
    if ($LASTEXITCODE -eq 0) {
        Write-Host "KB$kb_number installed successfully."
        exit 0
    } else {
        Write-Host "Error: Failed to install KB$kb_number."
        exit 1
    }
}
