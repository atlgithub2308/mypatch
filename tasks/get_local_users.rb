#!/usr/bin/env ruby

require 'json'

# Read stdin and parse parameters
input = STDIN.read
params = begin
  JSON.parse(input)
rescue
  {}
end

filter = params['filter'] || '*'
include_disabled = params['include_disabled'] != false
detailed = params['detailed'] == true

begin
  users = []
  
  # Use WMI query via PowerShell for detailed results
  # This is more reliable on Windows than pure Ruby approaches
  if detailed
    # PowerShell command to get detailed local user info
    ps_cmd = <<-POSH
Add-Type -AssemblyName System.DirectoryServices
$computerName = $env:COMPUTERNAME
$ad = [ADSI]"WinNT://$computerName"
$ad.psbase.Children | Where-Object { $_.Class -eq 'user' } | ForEach-Object {
  $user = $_
  $props = @{
    Name = $user.Name[0]
    FullName = $user.FullName[0]
    Description = $user.Description[0]
  }
  try {
    $props['Enabled'] = -not [bool]($user.UserFlags[0] -band 2)
  } catch {
    $props['Enabled'] = $true
  }
  $props | ConvertTo-Json
}
    POSH
    
    output = `powershell -Command "#{ps_cmd}" 2>&1`
    output.strip.split("\n").each do |line|
      next if line.empty?
      begin
        user_data = JSON.parse(line)
        # Filter by pattern
        if filter == '*' || user_data['Name'].include?(filter)
          # Skip disabled if not requested
          if include_disabled || user_data['Enabled']
            users << user_data
          end
        end
      rescue
        # Skip malformed lines
      end
    end
  else
    # Use 'net user' command for basic info
    output = `net user 2>&1`
    lines = output.strip.split("\n")
    
    # Parse net user output (format: Username | Description)
    in_user_section = false
    lines.each do |line|
      line.strip!
      next if line.empty?
      
      # Look for user accounts section
      if line.include?('---')
        in_user_section = true
        next
      end
      
      # Stop parsing at end marker
      if line.include?('The command completed successfully')
        break
      end
      
      if in_user_section && !line.include?('---')
        # Split by multiple spaces
        parts = line.split(/\s{2,}/)
        if parts.length > 0
          username = parts[0].strip
          description = parts[1].try(:strip) || ''
          
          # Filter by pattern
          if filter == '*' || username.include?(filter)
            users << {
              'Name' => username,
              'Description' => description,
              'Enabled' => true  # net user doesn't show disabled status easily
            }
          end
        end
      end
    end
  end
  
  result = {
    'success' => true,
    'user_count' => users.length,
    'users' => users
  }
  
  puts JSON.generate(result)
  
rescue => e
  error_result = {
    'success' => false,
    'error' => e.message
  }
  
  puts JSON.generate(error_result)
  exit 1
end
