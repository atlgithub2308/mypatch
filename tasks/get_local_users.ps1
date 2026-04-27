#!/usr/bin/env pwsh

param()

# Read input from stdin
$stdin = [Console]::In.ReadToEnd() | ConvertFrom-Json

$filter = $stdin.filter ?? "*"
$includeDisabled = $stdin.include_disabled ?? $true
$detailed = $stdin.detailed ?? $false

try {
    # Get local users
    $users = @()
    
    if ($detailed) {
        # Get detailed information
        Get-LocalUser -Name $filter | ForEach-Object {
            if ($includeDisabled -or -not $_.Enabled) {
                $lastLogon = $null
                try {
                    # Try to get last logon time
                    $lastLogon = (Get-LocalUser -Name $_.Name | Select-Object -ExpandProperty LastLogon -ErrorAction SilentlyContinue)
                } catch {
                    # If not available, leave null
                }
                
                $users += @{
                    Name = $_.Name
                    FullName = $_.FullName
                    Description = $_.Description
                    Enabled = $_.Enabled
                    SID = $_.SID.Value
                    LastLogon = $lastLogon
                    PasswordRequired = $_.PasswordRequired
                    UserMayChangePassword = $_.UserMayChangePassword
                    PasswordExpires = $_.PasswordExpires
                }
            }
        }
    } else {
        # Get basic information
        Get-LocalUser -Name $filter | ForEach-Object {
            if ($includeDisabled -or $_.Enabled) {
                $users += @{
                    Name = $_.Name
                    Enabled = $_.Enabled
                    Description = $_.Description
                }
            }
        }
    }
    
    $result = @{
        success = $true
        user_count = $users.Count
        users = $users
    }
    
    $result | ConvertTo-Json -Depth 10
    
} catch {
    $errorResult = @{
        success = $false
        error = $_.Exception.Message
    }
    
    $errorResult | ConvertTo-Json
    exit 1
}
