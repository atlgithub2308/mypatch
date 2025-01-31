
# Check if the MSSQLSERVER service is running
if ((Get-Service -Name MSSQLSERVER).Status -eq 'Stopped') {
    # Start the MSSQLSERVER service
    Start-Service -Name MSSQLSERVER

    # Check if the service was successfully started
    if ((Get-Service -Name MSSQLSERVER).Status -eq 'Running') {
        Write-Host "MSSQLSERVER service successfully started on $hostname."
    } else {
        Write-Host "Failed to start MSSQLSERVER service on $hostname."
    }
} else {
    Write-Host "MSSQLSERVER service is already running on $hostname, no action taken."
}
