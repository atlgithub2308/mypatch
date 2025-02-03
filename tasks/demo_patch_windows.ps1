param (
  [String]$package
)

# Ensure Chocolatey is installed
if (-Not (Get-Command choco -ErrorAction SilentlyContinue)) {
    Write-Host "Chocolatey not found. Installing Chocolatey..."
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
}

# Refresh environment to include choco
$env:Path += ";C:\ProgramData\chocolatey\bin"

# Check if the package is installed
$installed = choco list --localonly | Select-String -Pattern "^$package "
if ($installed) {
    Write-Host "Package $package is already installed. Upgrading..."
    choco upgrade $package -y
} else {
    Write-Host "Package $package is not installed. Installing..."
    choco install $package -y
}

Write-Host "Chocolatey package $package has been updated."
exit 0

