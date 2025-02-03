param (
  [String]$package
)

Write-Host "Checking if package '$package' is installed..."

# Get installed packages and remove versions
$installed_packages = choco list --limit-output | ForEach-Object { ($_ -split '\|')[0].ToLower() }  

# Convert input package name to lowercase for case-insensitive match
$package_lower = $package.ToLower()

if ($installed_packages -contains $package_lower) {
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
    Write-Host "Installed packages list: `n$installed_packages"
    exit 1
}
