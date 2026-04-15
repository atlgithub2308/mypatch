# Get MSSQL min and max server memory settings and emit JSON for Puppet task output.

function Write-TaskResult {
  param(
    [bool]$success,
    [string]$message,
    [array]$data = @(),
    [string]$stdout = '',
    [string]$stderr = '',
    [string]$command = ''
  )

  $result = [ordered]@{
    success = $success
    message = $message
    data = $data
    stdout = $stdout
    stderr = $stderr
    command = $command
  }

  $result | ConvertTo-Json -Depth 5
}

function Parse-SqlCmdOutput {
  param(
    [string]$output
  )

  $lines = $output -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
  $results = @()

  foreach ($line in $lines) {
    $parts = $line -split '\|' | ForEach-Object { $_.Trim() }
    if ($parts.Count -ge 4) {
      $results += [ordered]@{
        name = $parts[0]
        value = [int]$parts[1]
        minimum = [int]$parts[2]
        maximum = [int]$parts[3]
      }
    }
  }

  return $results
}

$serverInstance = 'localhost'
$sqlQuery = "SET NOCOUNT ON; SELECT name, value, minimum, maximum FROM sys.configurations WHERE name IN ('min server memory (MB)', 'max server memory (MB)') ORDER BY CASE WHEN name = 'min server memory (MB)' THEN 1 ELSE 2 END;"

# Prefer Invoke-Sqlcmd if available
$invokeSqlCmd = Get-Command -Name Invoke-Sqlcmd -ErrorAction SilentlyContinue

if ($invokeSqlCmd) {
  try {
    $rows = Invoke-Sqlcmd -ServerInstance $serverInstance -Query $sqlQuery -ErrorAction Stop
    $data = @()
    foreach ($row in $rows) {
      $data += [ordered]@{
        name = $row.name
        value = [int]$row.value
        minimum = [int]$row.minimum
        maximum = [int]$row.maximum
      }
    }
    Write-TaskResult -success $true -message 'Retrieved MSSQL memory configuration via Invoke-Sqlcmd.' -data $data -stdout '' -stderr '' -command "Invoke-Sqlcmd -ServerInstance $serverInstance -Query <query>"
    exit 0
  }
  catch {
    Write-TaskResult -success $false -message 'Failed to query SQL Server using Invoke-Sqlcmd.' -data @() -stdout '' -stderr $_.Exception.Message -command "Invoke-Sqlcmd -ServerInstance $serverInstance -Query <query>"
    exit 1
  }
}

$sqlCmdPath = Get-Command -Name sqlcmd.exe -ErrorAction SilentlyContinue
if ($sqlCmdPath) {
  $escapedQuery = $sqlQuery.Replace('"', '`"')
  $command = "sqlcmd.exe -S $serverInstance -W -h -1 -s '|' -Q `"$escapedQuery`""
  try {
    $process = Start-Process -FilePath sqlcmd.exe -ArgumentList "-S", $serverInstance, "-W", "-h", "-1", "-s", "|", "-Q", $sqlQuery -NoNewWindow -RedirectStandardOutput stdout.txt -RedirectStandardError stderr.txt -Wait -PassThru
    $stdout = Get-Content -Path stdout.txt -Raw
    $stderr = Get-Content -Path stderr.txt -Raw
    Remove-Item -Path stdout.txt, stderr.txt -ErrorAction SilentlyContinue

    if ($process.ExitCode -ne 0) {
      Write-TaskResult -success $false -message 'sqlcmd returned a non-zero exit code.' -data @() -stdout $stdout -stderr $stderr -command $command
      exit $process.ExitCode
    }

    $data = Parse-SqlCmdOutput -output $stdout
    Write-TaskResult -success $true -message 'Retrieved MSSQL memory configuration via sqlcmd.' -data $data -stdout $stdout -stderr $stderr -command $command
    exit 0
  }
  catch {
    Write-TaskResult -success $false -message 'Failed to query SQL Server using sqlcmd.exe.' -data @() -stdout '' -stderr $_.Exception.Message -command $command
    exit 1
  }
}

Write-TaskResult -success $false -message 'Neither Invoke-Sqlcmd nor sqlcmd.exe was found on the target.' -data @() -stdout '' -stderr 'Missing SQL client tools' -command ''
exit 1
