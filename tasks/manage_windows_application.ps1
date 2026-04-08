[CmdletBinding()]
Param(
  [Parameter(Mandatory = $True)]
  [ValidateSet('install', 'uninstall', 'list')]
  [String]$action,

  [Parameter(Mandatory = $False)]
  [String]$application,

  [Parameter(Mandatory = $False)]
  [String]$version,

  [String]$_installdir
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

function Write-TaskResult(
  [bool]$success,
  [string]$message,
  [string]$action,
  [string]$application,
  [string]$version,
  [int]$exit_code,
  [string]$stdout,
  [string]$stderr,
  [string]$command,
  [PSObject]$data = $null
) {
  $result = @{
    success = $success
    message = $message
    action = $action
    application = $application
    version = $version
    exit_code = $exit_code
    stdout = $stdout
    stderr = $stderr
    command = $command
  }
  if ($data) {
    $result['data'] = $data
  }
  $result | ConvertTo-Json -Depth 5
}

try {
  if ($action -eq 'list') {
    # List all installed Chocolatey packages
    $command = 'choco list --local-only'
    $outputLines = & choco list --local-only 2>&1
    $exit_code = $LASTEXITCODE
    $stdout = @($outputLines) -join "`n"
    $stderr = ''
    
    if ($exit_code -ne 0) {
      $stderr = $stdout
    }

    if ($exit_code -eq 0) {
      # Parse the output to extract package names and versions
      $packages = @()
      foreach ($line in $outputLines) {
        # Skip empty lines and the summary line
        if ($line -match '^\s*$' -or $line -match 'packages installed') {
          continue
        }
        $parts = $line -split '\s+', 2
        if ($parts.Count -ge 2) {
          $packages += @{
            name = $parts[0]
            version = $parts[1]
          }
        }
      }
      Write-TaskResult $true 'Chocolatey packages listed successfully.' $action '' '' $exit_code $stdout $stderr $command $packages
    } else {
      Write-TaskResult $false "Chocolatey list failed with exit code $exit_code." $action '' '' $exit_code $stdout $stderr $command
    }
    exit $exit_code
  }

  elseif ($action -eq 'install') {
    # Validate application parameter
    if (-not $application) {
      Write-TaskResult $false 'The ''application'' parameter is required for install action.' $action '' '' 1 '' '' ''
      exit 1
    }

    $arguments = @('install', $application, '-y', '--no-progress')
    if ($version) {
      $arguments += @('--version', $version)
    }
    $command = "choco $($arguments -join ' ')"

    $outputLines = & choco @arguments 2>&1
    $exit_code = $LASTEXITCODE
    $stdout = @($outputLines) -join "`n"
    $stderr = ''
    if ($exit_code -ne 0) {
      $stderr = $stdout
    }

    $success = $exit_code -eq 0
    $message = if ($success) {
      'Chocolatey package installed successfully.'
    } else {
      "Chocolatey install failed with exit code $exit_code."
    }

    Write-TaskResult $success $message $action $application $version $exit_code $stdout $stderr $command
    exit $exit_code
  }

  elseif ($action -eq 'uninstall') {
    # Validate application parameter
    if (-not $application) {
      Write-TaskResult $false 'The ''application'' parameter is required for uninstall action.' $action '' '' 1 '' '' ''
      exit 1
    }

    $arguments = @('uninstall', $application, '-y', '--no-progress')
    $command = "choco $($arguments -join ' ')"

    $outputLines = & choco @arguments 2>&1
    $exit_code = $LASTEXITCODE
    $stdout = @($outputLines) -join "`n"
    $stderr = ''
    if ($exit_code -ne 0) {
      $stderr = $stdout
    }

    $success = $exit_code -eq 0
    $message = if ($success) {
      'Chocolatey package uninstalled successfully.'
    } else {
      "Chocolatey uninstall failed with exit code $exit_code."
    }

    Write-TaskResult $success $message $action $application '' $exit_code $stdout $stderr $command
    exit $exit_code
  }
}
catch [System.Management.Automation.CommandNotFoundException] {
  Write-TaskResult $false 'Chocolatey executable ''choco'' was not found in the PATH.' $action $application $version 1 '' $_.Exception.Message ''
  exit 1
}
catch {
  $stderr = $_ | Out-String
  Write-TaskResult $false "Failed to execute task: $($_.Exception.Message)" $action $application $version 1 '' $stderr ''
  exit 1
}
