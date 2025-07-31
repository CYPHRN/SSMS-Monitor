#Requires -Version 3.0

$monitoringPath = 'C:\SQLMonitoring'
$folders = Get-ChildItem -Path $monitoringPath -Directory -Recurse | Select-Object -ExpandProperty FullName
$folders += $monitoringPath

Get-Process -Name powershell | Where-Object {$_.MainWindowTitle -eq ""} | Stop-Process -Force
Write-Output "Stopped hidden PowerShell processes"

foreach ($folder in $folders) {
    Write-Output "Processing folder: $folder"
    
    $pidFilePath = Join-Path -Path $folder -ChildPath 'LoggingProcessID.txt'
    if (Test-Path $pidFilePath) {
        $monitoringPID = Get-Content $pidFilePath
        $process = Get-Process -Id $monitoringPID -ErrorAction SilentlyContinue
        if ($process) {
            Stop-Process -Id $monitoringPID -Force
            Write-Output "Stopped monitoring process: $monitoringPID"
        }
        Remove-Item -Path $pidFilePath -Force
    }

    $filesToRemove = @(
        'SystemResourceLog*.txt',
        'LoggingProcessID.txt',
        'system_metrics.png'
    )

    foreach ($pattern in $filesToRemove) {
        $files = Get-ChildItem -Path $folder -Filter $pattern 
        foreach ($file in $files) {
            Remove-Item $file.FullName -Force
            Write-Output "Removed file: $file"
        }
    }
}

Get-Job | Where-Object { $_.State -eq 'Running' } | Stop-Job
Get-Job | Remove-Job -Force

Write-Output "Cleanup completed"
exit 0