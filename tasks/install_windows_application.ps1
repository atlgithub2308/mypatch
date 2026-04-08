[CmdletBinding()]
Param(
  [Parameter(Mandatory = $True)]
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
  [string]$application,
  [string]$version,
  [int]$exit_code,
  [string]$stdout,
  [string]$stderr,
  [string]$command
) {
  $result = @{
    success = $success
    message = $message
    application = $application
    version = $version
    exit_code = $exit_code
    stdout = $stdout
    stderr = $stderr
    command = $command
  }
  $result | ConvertTo-Json -Depth 5
}

$arguments = @('install', $application, '-y', '--no-progress')
if ($version) {
  $arguments += @('--version', $version)
}
$command = "choco $($arguments -join ' ')"

try {
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

  Write-TaskResult $success $message $application $version $exit_code $stdout $stderr $command
  exit $exit_code
}
catch [System.Management.Automation.CommandNotFoundException] {
  Write-TaskResult $false 'Chocolatey executable ''choco'' was not found in the PATH.' $application $version 1 '' $_.Exception.Message $command
  exit 1
}
catch {
  $stderr = $_ | Out-String
  Write-TaskResult $false "Failed to execute Chocolatey: $($_.Exception.Message)" $application $version 1 '' $stderr $command
  exit 1
}
