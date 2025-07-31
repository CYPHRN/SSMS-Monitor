# Create monitoring directory if it doesn't exist
if (!(Test-Path 'C:\SQLMonitoring\Log Script Test')) {
    New-Item -ItemType Directory -Path 'C:\SQLMonitoring\Log Script Test'
}

# Generate unique timestamp-based filename for the log
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$logFileName = "SystemResourceLog-$timestamp.txt"

# Define the main monitoring script block that will run in a separate process
$scriptBlock = {
    param($logFileName)
    
    # Set paths for log file and process ID file
    $logPath = "C:\SQLMonitoring\Log Script Test\$logFileName"
    $pidPath = 'C:\SQLMonitoring\Log Script Test\LoggingProcessID.txt'
    # Set maximum log file size limit in MB
    $maxSizeMB = 1

    # Set high priority for the monitoring process to ensure consistent data collection
    $currentProcess = Get-Process -Id $PID
    $currentProcess.PriorityClass = 'High'

    # Save the process ID to file for later termination
    $PID | Out-File -FilePath $pidPath -Force

    # Main function to collect and log system metrics
    function Log-SystemMetrics {
        # Check if log file has reached size limit
        if (Test-Path $logPath) {
            $fileSize = (Get-Item $logPath).Length / 1MB
            if ($fileSize -ge $maxSizeMB) {
                Write-Host "Log file has reached size limit of $maxSizeMB MB. Stopping monitoring."
                Stop-Process -Id $PID -Force
                return
            }
        }

        try {
            # Collect CPU usage as an average across all processors
            $cpu = (Get-WmiObject Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average

            # Collect memory usage statistics
            $os = Get-WmiObject Win32_OperatingSystem
            $freeMemoryMB = $os.FreePhysicalMemory / 1KB
            $totalMemoryMB = $os.TotalVisibleMemorySize / 1KB
            $usedMemoryMB = [math]::Round($totalMemoryMB - $freeMemoryMB, 2)

            # Collect detailed disk I/O metrics for each physical disk
            $diskIOText = ""
            $diskIO = Get-WmiObject Win32_PerfFormattedData_PerfDisk_PhysicalDisk | Where-Object { $_.Name -ne '_Total' }
            
            foreach ($disk in $diskIO) {
                $diskName = $disk.Name
                # Calculate disk metrics and convert to readable format
                $readBytesPerSec = [math]::Round($disk.DiskReadBytesPerSec / 1MB, 2)
                $writeBytesPerSec = [math]::Round($disk.DiskWriteBytesPerSec / 1MB, 2)
                $readsPerSec = [math]::Round($disk.DiskReadsPerSec, 2)
                $writesPerSec = [math]::Round($disk.DiskWritesPerSec, 2)
                # Convert latency to milliseconds
                $avgReadLatency = [math]::Round($disk.AvgDiskSecPerRead * 1000, 2)
                $avgWriteLatency = [math]::Round($disk.AvgDiskSecPerWrite * 1000, 2)
                
                # Format disk metrics for logging
                $diskIOText = $diskIOText + "Disk $diskName" + [Environment]::NewLine
                $diskIOText = $diskIOText + "  Read: $readBytesPerSec MB/s ($readsPerSec IOPS, $avgReadLatency ms latency)" + [Environment]::NewLine
                $diskIOText = $diskIOText + "  Write: $writeBytesPerSec MB/s ($writesPerSec IOPS, $avgWriteLatency ms latency)" + [Environment]::NewLine
            }

            # Collect network interface statistics
            $networkText = ""
            $networkAdapters = Get-WmiObject Win32_PerfFormattedData_Tcpip_NetworkInterface
            
            foreach ($net in $networkAdapters) {
                $netName = $net.Name
                # Calculate network metrics and convert to MB/s
                $receivedBytesPerSecMB = [math]::Round($net.BytesReceivedPerSec / 1MB, 2)
                $sentBytesPerSecMB = [math]::Round($net.BytesSentPerSec / 1MB, 2)
                # Collect packet statistics
                $packetsReceived = $net.PacketsReceivedPerSec
                $packetsSent = $net.PacketsSentPerSec
                $packetErrors = $net.PacketsReceivedErrors + $net.PacketsOutboundErrors
                $packetsDiscarded = $net.PacketsReceivedDiscarded + $net.PacketsOutboundDiscarded
                
                # Format network metrics for logging
                $networkText = $networkText + "Interface $netName" + [Environment]::NewLine
                $networkText = $networkText + "  Download: $receivedBytesPerSecMB MB/s ($packetsReceived packets/s)" + [Environment]::NewLine
                $networkText = $networkText + "  Upload: $sentBytesPerSecMB MB/s ($packetsSent packets/s)" + [Environment]::NewLine
                # Only log errors if they exist
                if ($packetErrors -gt 0 -or $packetsDiscarded -gt 0) {
                    $networkText = $networkText + "  Issues: $packetErrors errors, $packetsDiscarded discarded packets" + [Environment]::NewLine
                }
            }
            
            # Get current timestamp for log entry
            $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
            
            # Combine all metrics into a single log entry
            $logEntry = "Timestamp: $timestamp" + [Environment]::NewLine
            $logEntry = $logEntry + "CPU Usage: $cpu%" + [Environment]::NewLine
            $logEntry = $logEntry + "Memory Usage: $usedMemoryMB GB Used / $totalMemoryMB GB Total" + [Environment]::NewLine
            $logEntry = $logEntry + "Disk I/O:" + [Environment]::NewLine
            $logEntry = $logEntry + $diskIOText
            $logEntry = $logEntry + "Network Usage:" + [Environment]::NewLine
            $logEntry = $logEntry + $networkText
            $logEntry = $logEntry + "-----------------------------" + [Environment]::NewLine

            # Implement retry logic for writing to log file
            $maxRetries = 3
            $retryCount = 0
            $success = $false

            while (-not $success -and $retryCount -lt $maxRetries) {
                try {
                    Add-Content -Path $logPath -Value $logEntry -ErrorAction Stop
                    $success = $true
                }
                catch {
                    $retryCount++
                    Start-Sleep -Milliseconds 500  # Wait before retry
                    if ($retryCount -eq $maxRetries) {
                        Write-Warning "Failed to write to log after $maxRetries attempts"
                    }
                }
            }
        }
        catch {
            Write-Warning "Error collecting metrics: $_"
        }
    }

    # Write initial entry to log file
    'Monitoring started at ' + (Get-Date) | Out-File -FilePath $logPath -Force

    # Main monitoring loop - collects metrics every 5 seconds
    while ($true) {
        Log-SystemMetrics
        Start-Sleep -Seconds 5
    }
}

# Convert script block to base64 encoded command for secure execution
$encodedCommand = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes("& {$scriptBlock} -logFileName '$logFileName'"))
# Start monitoring process with high priority and hidden window
$process = Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -EncodedCommand $encodedCommand" -WindowStyle Hidden -PassThru
$process.PriorityClass = 'High'

# Wait briefly to ensure process starts
Start-Sleep -Seconds 2
exit 0