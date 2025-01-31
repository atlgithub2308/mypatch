
# Check if the MSSQLSERVER service is running
if ((Get-Service -Name MSSQLSERVER).Status -eq 'Running') {
    # Stop the MSSQLSERVER service
    Stop-Service -Name MSSQLSERVER -Force

    # Wait for the service to stop and confirm
    if ((Get-Service -Name MSSQLSERVER).Status -eq 'Stopped') {
        Write-Host "MSSQLSERVER service successfully stopped on $hostname."
    } else {
        Write-Host "Failed to stop MSSQLSERVER service on $hostname."
    }
} else {
    Write-Host "MSSQLSERVER service is not running on $hostname, no action taken."
}
