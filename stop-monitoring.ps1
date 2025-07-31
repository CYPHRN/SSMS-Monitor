$pidFilePath = 'C:\SQLMonitoring\Log Script Test\LoggingProcessID.txt'

# Stop the monitoring PowerShell process
if (Test-Path $pidFilePath) {
    $monitoringPID = Get-Content $pidFilePath
    $process = Get-Process -Id $monitoringPID -ErrorAction SilentlyContinue
    if ($process) {
        Stop-Process -Id $monitoringPID -Force
    }
    Remove-Item -Path $pidFilePath -Force
}

# Clean up any remaining jobs
Get-Job | Where-Object { $_.State -eq 'Running' } | Stop-Job
Get-Job | Remove-Job -Force

exit 0