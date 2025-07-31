#Requires -Version 3.0

# Import required .NET assemblies for graphics and UI components
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

# Email configuration
$SmtpServer = 'SMPT Server'
$From = 'SENDING EMAIL'
$To = 'RECIEVING EMAIL'
$Subject = 'Log Script Test - System Resource Monitoring Report'
$Port = 25

# File path configuration
$MonitoringPath = 'C:\SQLMonitoring\Log Script Test'
$LogPattern = 'SystemResourceLog-*.txt'
$OutputFile = 'C:\SQLMonitoring\Log Script Test\system_metrics.png'

# Gets the most recent log file from the monitoring directory
function Get-LatestLogFile {
    $logFiles = Get-ChildItem -Path $MonitoringPath -Filter $LogPattern
    if (-not $logFiles) {
        throw 'No log files found'
    }
    return $logFiles | Sort-Object CreationTime -Descending | Select-Object -First 1
}

# Draws the legend for each graph with specified labels and colors
function Draw-Legend {
    param(
        [Drawing.Graphics]$g,
        [int]$x,
        [int]$y,
        [string[]]$labels,
        [Drawing.Color[]]$colors
    )
    
    $font = New-Object Drawing.Font('Arial', 8)
    $lineLength = 20
    $spacing = 15
    $currentY = $y
    
    # Draw each legend item with its corresponding color and label
    for ($i = 0; $i -lt $labels.Length; $i++) {
        $pen = New-Object Drawing.Pen($colors[$i], 2)
        $g.DrawLine($pen, $x, $currentY + 4, $x + $lineLength, $currentY + 4)
        $g.DrawString($labels[$i], $font, [Drawing.Brushes]::Black, $x + $lineLength + 5, $currentY)
        $currentY += $spacing
    }
}

# Main function for drawing individual graphs
function Draw-Graph {
    param(
        [Drawing.Graphics]$g,
        [int]$x,
        [int]$y,
        [int]$width,
        [int]$height,
        [string]$title,
        [array]$times,
        [array]$values,
        [array]$values2 = $null,
        [double]$maxValue = 0,
        [double]$minValue = 0,
        [bool]$memoryGraph = $false,
        [string[]]$legendLabels = $null,
        [bool]$isCPU = $false,
        [bool]$isNetwork = $false,
        [bool]$isDiskIO = $false
    )
    
    # Setup basic graph dimensions and styling
    $padding = 50
    $plotWidth = $width - ($padding * 2)
    $plotHeight = $height - ($padding * 2)
    
    $font = New-Object Drawing.Font('Arial', 10, [Drawing.FontStyle]::Bold)
    $titleBrush = [Drawing.Brushes]::Black
    $g.DrawString($title, $font, $titleBrush, $x + $width/2 - 50, $y + 10)
    
    # Draw graph axes
    $pen = New-Object Drawing.Pen([Drawing.Color]::Black)
    $g.DrawLine($pen, $x + $padding, $y + $height - $padding, $x + $width - $padding, $y + $height - $padding)
    $g.DrawLine($pen, $x + $padding, $y + $height - $padding, $x + $padding, $y + $padding)

    # Set range based on graph type with appropriate scaling
    if ($isCPU) {
        $maxValue = 100
        $minValue = 0
    }
    elseif ($memoryGraph) {
        # Calculate memory range with padding
        if ($values -and $values2) {
            $maxValue = [Math]::Ceiling([Math]::Max(
                ($values | Measure-Object -Maximum).Maximum,
                ($values2 | Measure-Object -Maximum).Maximum
            ))
            $minValue = [Math]::Floor([Math]::Min(
                ($values | Measure-Object -Minimum).Minimum,
                ($values2 | Measure-Object -Minimum).Minimum
            ))
            $range = $maxValue - $minValue
            $maxValue += $range * 0.1
            $minValue = [Math]::Max(0, $minValue - ($range * 0.1))
        }
    }
    elseif ($isNetwork) {
        # Calculate network range with 5-unit intervals
        $maxNet = [Math]::Max(
            ($values | Measure-Object -Maximum).Maximum,
            ($values2 | Measure-Object -Maximum).Maximum
        )
        $maxValue = [Math]::Ceiling($maxNet / 5) * 5
        $maxValue = [Math]::Max(20, $maxValue)
        $minValue = 0
    }
    elseif ($isDiskIO) {
        # Calculate disk I/O range with 5-unit intervals
        $maxDisk = [Math]::Max(
            ($values | Measure-Object -Maximum).Maximum,
            ($values2 | Measure-Object -Maximum).Maximum
        )
        $maxValue = [Math]::Ceiling($maxDisk / 5) * 5
        $maxValue = [Math]::Max(30, $maxValue)
        $minValue = 0
    }
    
    if ($values.Count -gt 1) {
        # Calculate scaling factors for plotting
        $xScale = $plotWidth / ($values.Count - 1)
        $yScale = $plotHeight / ($maxValue - $minValue)
        
        # Draw grid lines and labels
        $gridPen = New-Object Drawing.Pen([Drawing.Color]::LightGray)
        $numGridLines = 5
        $gridInterval = ($maxValue - $minValue) / $numGridLines
        
        # Ensure grid intervals are multiples of 5 for Disk I/O and Network
        if ($isDiskIO -or $isNetwork) {
            $gridInterval = [Math]::Ceiling($gridInterval / 5) * 5
        }
        
        # Draw grid lines and value labels
        for ($i = 0; $i -le $numGridLines; $i++) {
            $yPos = $y + $height - $padding - ($i * $gridInterval * $yScale)
            if ($yPos -ge ($y + $padding) -and $yPos -le ($y + $height - $padding)) {
                $g.DrawLine($gridPen, $x + $padding, $yPos, $x + $width - $padding, $yPos)
                
                # Format labels based on graph type
                $labelValue = if ($memoryGraph) {
                    [Math]::Round($minValue + ($i * $gridInterval), 0).ToString()
                } elseif ($isCPU) {
                    [Math]::Round($minValue + ($i * $gridInterval), 1).ToString() + "%"
                } elseif ($isDiskIO -or $isNetwork) {
                    [Math]::Round($minValue + ($i * $gridInterval), 0).ToString()
                } else {
                    [Math]::Round($minValue + ($i * $gridInterval), 1).ToString()
                }
                
                $g.DrawString($labelValue, $font, $titleBrush, $x + 5, $yPos - 7)
            }
        }
        
        # Draw first line series (blue)
        $bluePen = New-Object Drawing.Pen([Drawing.Color]::Blue, 2)
        $points = @()
        for ($i = 0; $i -lt $values.Count; $i++) {
            $xPos = $x + $padding + ($i * $xScale)
            $yPos = $y + $height - $padding - (($values[$i] - $minValue) * $yScale)
            $points += New-Object Drawing.PointF($xPos, $yPos)
        }
        $g.DrawLines($bluePen, $points)
        
        # Draw second line series (red) if exists
        if ($values2) {
            $redPen = New-Object Drawing.Pen([Drawing.Color]::Red, 2)
            $points2 = @()
            for ($i = 0; $i -lt $values2.Count; $i++) {
                $xPos = $x + $padding + ($i * $xScale)
                $yPos = $y + $height - $padding - (($values2[$i] - $minValue) * $yScale)
                $points2 += New-Object Drawing.PointF($xPos, $yPos)
            }
            $g.DrawLines($redPen, $points2)
        }
        
        # Draw time axis labels
        $timeLabelsCount = 5
        for ($i = 0; $i -lt $timeLabelsCount; $i++) {
            $index = [Math]::Floor($i * ($times.Count - 1) / ($timeLabelsCount - 1))
            $xPos = $x + $padding + ($index * $xScale)
            $timeLabel = $times[$index].ToString('HH:mm')
            $labelWidth = $g.MeasureString($timeLabel, $font).Width
            $g.DrawString($timeLabel, $font, $titleBrush, $xPos - ($labelWidth / 2), $y + $height - 30)
        }
        
        # Draw legend if labels provided
        if ($legendLabels) {
            $colors = @([Drawing.Color]::Blue)
            if ($values2) { $colors += [Drawing.Color]::Red }
            Draw-Legend $g ($x + $width - 150) ($y + 30) $legendLabels $colors
        }
    }
}
# Parses the log file and extracts time series data for all metrics
function Parse-LogFile {
    param([string]$FilePath)
    
    # Initialize data structure for all metrics
    $data = @{
        'Time' = New-Object Collections.ArrayList
        'CPU' = New-Object Collections.ArrayList
        'MemoryUsed' = New-Object Collections.ArrayList
        'MemoryTotal' = New-Object Collections.ArrayList
        'DiskRead' = New-Object Collections.ArrayList
        'DiskWrite' = New-Object Collections.ArrayList
        'NetworkDown' = New-Object Collections.ArrayList
        'NetworkUp' = New-Object Collections.ArrayList
    }
    
    # Track disk metrics across multiple entries
    $currentDiskRead = 0.0
    $currentDiskWrite = 0.0
    $isDiskSection = $false
    
    # Process each line of the log file
    Get-Content $FilePath | ForEach-Object {
        $line = $_.Trim()
        
        # Parse timestamp and reset disk counters for new entries
        if ($line -match '^Timestamp: (.+)') {
            if ($data.Time.Count -gt 0) {
                [void]$data.DiskRead.Add($currentDiskRead)
                [void]$data.DiskWrite.Add($currentDiskWrite)
            }
            
            $timestamp = [datetime]::ParseExact($matches[1].Trim(), 'yyyy-MM-dd HH:mm:ss', $null)
            [void]$data.Time.Add($timestamp)
            $currentDiskRead = 0.0
            $currentDiskWrite = 0.0
            $isDiskSection = $false
        }
        # Parse CPU usage
        elseif ($line -match '^CPU Usage: (\d+\.?\d*)%') {
            [void]$data.CPU.Add([double]$matches[1])
        }
        # Parse memory usage
        elseif ($line -match '^Memory Usage: (\d+\.?\d*) GB Used / (\d+\.?\d*) GB Total') {
            [void]$data.MemoryUsed.Add([double]$matches[1])
            [void]$data.MemoryTotal.Add([double]$matches[2])
        }
        # Track disk I/O section
        elseif ($line -match '^Disk I/O:') {
            $isDiskSection = $true
        }
        # Parse disk read metrics
        elseif ($isDiskSection -and $line -match 'Read: (\d+\.?\d*)') {
            $currentDiskRead += [double]$matches[1]
        }
        # Parse disk write metrics
        elseif ($isDiskSection -and $line -match 'Write: (\d+\.?\d*)') {
            $currentDiskWrite += [double]$matches[1]
        }
        # Track network section
        elseif ($line -match '^Network Usage:') {
            $isDiskSection = $false
        }
        # Parse network download metrics
        elseif ($line -match 'Download: (\d+\.?\d*)') {
            [void]$data.NetworkDown.Add([double]$matches[1])
        }
        # Parse network upload metrics
        elseif ($line -match 'Upload: (\d+\.?\d*)') {
            [void]$data.NetworkUp.Add([double]$matches[1])
        }
    }
    
    # Add final disk values for the last entry
    if ($data.Time.Count -gt 0) {
        [void]$data.DiskRead.Add($currentDiskRead)
        [void]$data.DiskWrite.Add($currentDiskWrite)
    }
    
    return $data
}

# Creates the complete metrics chart with all four graphs
function Create-MetricsChart {
    param($Data)
    
    # Initialize bitmap for the complete chart
    $width = 1000
    $height = 800
    $bmp = New-Object Drawing.Bitmap($width, $height)
    $g = [Drawing.Graphics]::FromImage($bmp)
    $g.Clear([Drawing.Color]::White)
    
    # Calculate dimensions for each sub-graph
    $subWidth = $width / 2
    $subHeight = $height / 2
    
    # Enable anti-aliasing for smoother lines
    $g.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.TextRenderingHint = [Drawing.Text.TextRenderingHint]::ClearTypeGridFit
    
    # Draw all four graphs
    Draw-Graph $g 0 0 $subWidth $subHeight 'CPU Usage (%)' $Data.Time $Data.CPU -legendLabels @('CPU %') -isCPU $true
    
    Draw-Graph $g $subWidth 0 $subWidth $subHeight 'Memory Usage (GB)' $Data.Time $Data.MemoryUsed $Data.MemoryTotal -memoryGraph $true `
        -legendLabels @('Used Memory', 'Total Memory')
    
    Draw-Graph $g 0 $subHeight $subWidth $subHeight 'Disk I/O (MB/s)' $Data.Time $Data.DiskRead $Data.DiskWrite `
        -legendLabels @('Read MB/s', 'Write MB/s') -isDiskIO $true
    
    Draw-Graph $g $subWidth $subHeight $subWidth $subHeight 'Network Usage (MB/s)' $Data.Time $Data.NetworkDown $Data.NetworkUp `
        -legendLabels @('Download MB/s', 'Upload MB/s') -isNetwork $true
    
    # Save and cleanup
    $bmp.Save($OutputFile, [Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose()
    $bmp.Dispose()
}

# Safely removes the log file with multiple attempts
function Remove-LogFile {
    param([string]$FilePath)
    
    try {
        # Force garbage collection before deletion
        [System.GC]::Collect()
        [System.GC]::WaitForPendingFinalizers()
        
        Start-Sleep -Seconds 5
        
        # Try multiple deletion methods in case of file locks
        if (Test-Path $FilePath) {
            [System.IO.File]::Delete($FilePath)
        }
        
        if (Test-Path $FilePath) {
            Remove-Item -Path $FilePath -Force -ErrorAction Stop
        }
        
        if (Test-Path $FilePath) {
            $fileInfo = New-Object System.IO.FileInfo($FilePath)
            $fileInfo.Delete()
        }
        
        Write-Output ('Deleted log file: ' + $FilePath)
        return $true
    }
    catch {
        Write-Error ('Failed to delete log file: ' + $FilePath + ' Error: ' + $_.Exception.Message)
        return $false
    }
}

# Main execution block
try {
    Set-Location -Path $MonitoringPath
    
    # Get and process the latest log file
    $logFile = Get-LatestLogFile
    $logFilePath = $logFile.FullName
    Write-Output ('Processing log file: ' + $logFilePath)
    
    # Generate charts and send email
    $data = Parse-LogFile -FilePath $logFilePath
    if ($data.Time.Count -gt 0) {
        Create-MetricsChart -Data $data
        
        if (-not (Test-Path $OutputFile)) {
            throw 'Graph file was not created'
        }
        
        # Prepare and send email with attachments
        $currentDate = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        $body = 'System Resource Monitoring Report - Generated on ' + $currentDate
        
        Send-MailMessage -SmtpServer $SmtpServer -Port $Port -From $From -To $To -Subject $Subject -Body $body -Attachments $logFilePath,$OutputFile
        Start-Sleep -Seconds 5
        
        # Cleanup generated files
        if (Test-Path $OutputFile) {
            Remove-Item -Path $OutputFile -Force
            Write-Output ('Deleted graph file: ' + $OutputFile)
        }
        
        $deleted = Remove-LogFile -FilePath $logFilePath
        if (-not $deleted) {
            Write-Warning ('Could not delete log file, it will be removed on next run: ' + $logFilePath)
        }

        Write-Output 'Process completed successfully'
    }
    else {
        throw 'No data was parsed from the log file'
    }
}
catch {
    # Handle any errors and send error notification
    $errorMessage = $_.Exception.Message
    Write-Error ('Error occurred: ' + $errorMessage)
    Send-MailMessage -SmtpServer $SmtpServer -Port $Port -From $From -To $To -Subject ('ERROR: ' + $Subject) -Body ('An error occurred: ' + $errorMessage)
    exit 1
}