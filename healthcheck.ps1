# Ensure running as Administrator
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))
{
    Write-Host "Please run this script as an Administrator!"
    exit
}

# Define the path to save the metrics file
$metricsFilePath = "C:\Scripts\ac\metrics\metrics"

# Gather system information
$hostname = $env:COMPUTERNAME
$os = Get-CimInstance Win32_OperatingSystem
$cpus = (Get-CimInstance Win32_Processor | Measure-Object -Property NumberOfLogicalProcessors -Sum).Sum
$mem = Get-CimInstance Win32_PhysicalMemory | Measure-Object -Property Capacity -Sum
$lastBootTime = $os.LastBootUpTime
$osVersion = $os.Version
$disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
$lastUpdate = Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 1

# Calculate UNIX timestamp for last reboot time
$bootTime = [timezone]::CurrentTimeZone.ToUniversalTime($lastBootTime)
$epoch = [timezone]::CurrentTimeZone.ToUniversalTime((Get-Date "1/1/1970"))
$unixTime = [math]::Round((New-TimeSpan $epoch $bootTime).TotalSeconds)

# Prepare metrics string
$metrics = @"
# HELP windows_cpu_usage_avg Current Average CPU Usage (Percentage)
# TYPE windows_cpu_usage_avg gauge
windows_cpu_usage_avg{hostname="$hostname"} $(Get-Counter '\Processor(_Total)\% Processor Time' | Select-Object -ExpandProperty CounterSamples | Select-Object -ExpandProperty CookedValue)

# HELP windows_memory_usage_avg Current Average Memory Usage (Percentage)
# TYPE windows_memory_usage_avg gauge
windows_memory_usage_avg{hostname="$hostname"} $(Get-Counter '\Memory\Available MBytes' | Select-Object -ExpandProperty CounterSamples | ForEach-Object { 100 - ($_.CookedValue / ($mem.Sum / 1MB) * 100) })

# HELP windows_disk_free_space_gb Total Free Disk Space on C:\ (GB)
# TYPE windows_disk_free_space_gb gauge
windows_disk_free_space_gb{hostname="$hostname"} $($disk.FreeSpace / 1GB)

# HELP windows_disk_capacity_gb Total Disk Space Capacity of C:\ (GB)
# TYPE windows_disk_capacity_gb gauge
windows_disk_capacity_gb{hostname="$hostname"} $($disk.Size / 1GB)

# HELP windows_cpu_count Total Number of CPUs
# TYPE windows_cpu_count gauge
windows_cpu_count{hostname="$hostname"} $cpus

# HELP windows_total_ram_gb Total RAM (GB)
# TYPE windows_total_ram_gb gauge
windows_total_ram_gb{hostname="$hostname"} $($mem.Sum / 1GB)

# HELP windows_last_reboot_time Last Reboot Time as Unix timestamp
# TYPE windows_last_reboot_time gauge
windows_last_reboot_time{hostname="$hostname"} $unixTime

# HELP windows_info Static information about the Windows system
# TYPE windows_info gauge
windows_info{hostname="$hostname", windows_os_version="$osVersion", last_patch_date="$($lastUpdate.InstalledOn.ToString('yyyy-MM-dd'))"} 1

# HELP windows_last_kb_info Information about the last installed KB update
# TYPE windows_last_kb_info gauge
windows_last_kb_info{hostname="$hostname", kb_id="$($lastUpdate.HotFixID)"} 1
"@

# Ensure Unix line endings by replacing Windows-style endings
$metrics = $metrics -replace "`r`n", "`n"

# Write metrics to file without BOM
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($metricsFilePath, $metrics, $utf8NoBom)

# Output to console for verification
Write-Output "Metrics saved to $metricsFilePath without BOM"
Write-Output $metrics
