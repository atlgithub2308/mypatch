param (
  [String]$package
)

Write-Host "Checking if package '$package' is installed..."
$installed_packages = choco list --local-only | Out-String
if ($installed_packages -match "^$package\s") {
    Write-Host "Package '$package' is installed. Proceeding with update..."
    choco upgrade $package -y --ignore-checksums

    if ($LASTEXITCODE -eq 0) {
        Write-Host "Package '$package' updated successfully."
        exit 0
    } else {
        Write-Host "Error: Failed to update package '$package'."
        exit 1
    }
} else {
    Write-Host "Error: Package '$package' is not installed. Please install it first."
    exit 1
}
