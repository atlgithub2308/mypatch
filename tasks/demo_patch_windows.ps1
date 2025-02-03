param (
  [String]$package
)

Write-Host "Checking if package '$package' is installed..."
$choco_check = choco list --local-only | Select-String -Pattern "^$package "

if (-not $choco_check) {
    Write-Host "Error: Package '$package' is not installed. Please install it first."
    exit 1
}

Write-Host "Updating package '$package' using Chocolatey..."
choco upgrade $package -y --ignore-checksums

if ($?) {
    Write-Host "Package '$package' updated successfully."
    exit 0
} else {
    Write-Host "Error: Failed to update package '$package'."
    exit 1
}
