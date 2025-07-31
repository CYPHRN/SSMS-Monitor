# SSMS Monitoring

A comprehensive PowerShell-based system monitoring solution that continuously tracks system performance metrics, generates visual reports, and sends automated email notifications. Perfect for SQL Server environments and general system health monitoring.

## Features

- **Real-time Monitoring**: Continuous collection of CPU, memory, disk I/O, and network metrics
- **Visual Reporting**: Automated generation of professional multi-graph charts
- **Email Integration**: Automatic email delivery of reports with log attachments
- **Resource Management**: Intelligent file size limits and cleanup processes
- **High Performance**: Optimized collection intervals and high-priority processing
- **Detailed Metrics**: Comprehensive system statistics including IOPS, latency, and packet analysis

## Architecture

The workflow consists of four main components:

### 1. start-monitoring.ps1

**Purpose**: Initiates system monitoring in a background process

- Creates monitoring directory structure
- Launches high-priority background monitoring process
- Generates unique timestamped log files
- Implements size-based log rotation (1MB default limit)

### 2. process-graph-send-email.ps1

**Purpose**: Processes logs, creates visualizations, and sends email reports

- Parses system metrics from log files
- Generates professional 4-panel performance charts
- Sends email with log and chart attachments
- Performs cleanup of processed files

### 3. stop-monitoring.ps1

**Purpose**: Gracefully terminates monitoring processes

- Stops background monitoring using saved process ID
- Cleans up running jobs and temporary files
- Ensures clean shutdown without orphaned processes

### 4. cleanup-monitoring.ps1

**Purpose**: Comprehensive cleanup and maintenance

- Terminates all hidden PowerShell monitoring processes
- Removes log files, charts, and temporary data across all monitoring folders
- Performs system-wide cleanup of monitoring artifacts

## System Metrics Collected

### CPU Metrics

- Overall CPU utilization percentage
- Multi-processor averaging

### Memory Metrics

- Used memory (GB)
- Total available memory (GB)
- Free memory calculations

### Disk I/O Metrics (per disk)

- Read/Write throughput (MB/s)
- Read/Write IOPS
- Average read/write latency (milliseconds)

### Network Metrics (per interface)

- Download/Upload throughput (MB/s)
- Packet statistics (packets/second)
- Error and discard tracking

## Installation & Setup

### Prerequisites

- PowerShell 3.0 or later
- .NET Framework (for graphics generation)
- SMTP server access for email functionality
- Appropriate file system permissions for `C:\SQLMonitoring`

### Configuration

1. **Email Settings** (in process-graph-send-email.ps1):

```powershell
$SmtpServer = 'your-smtp-server.com'
$From = 'monitoring@yourcompany.com'
$To = 'admin@yourcompany.com'
$Port = 25  # or 587 for TLS
```

2. **File Paths** (customize if needed):

```powershell
$MonitoringPath = 'C:\SQLMonitoring\Log Script Test'
```

3. **Collection Interval**: Default 5 seconds (adjustable in monitoring loop)

4. **Log Size Limit**: Default 1MB (adjustable via `$maxSizeMB`)

## Usage Examples

### Start Monitoring

```powershell
# Begin continuous system monitoring
.\start-monitoring.ps1
```

### Process and Send Report

```powershell
# Generate charts and email latest metrics
.\process-graph-send-email.ps1
```

### Stop Monitoring

```powershell
# Gracefully stop monitoring process
.\stop-monitoring.ps1
```

### Full Cleanup

```powershell
# Remove all monitoring data and processes
.\cleanup-monitoring.ps1
```

### Automated Workflow

```powershell
# Complete monitoring cycle
.\start-monitoring.ps1
Start-Sleep -Seconds 300  # Monitor for 5 minutes
.\process-graph-send-email.ps1
.\stop-monitoring.ps1
```

## Output Files

### Log Files

- **Format**: `SystemResourceLog-YYYYMMDD-HHMMSS.txt`
- **Content**: Timestamped system metrics in structured text format
- **Location**: `C:\SQLMonitoring\Log Script Test\`

### Chart Files

- **Format**: `system_metrics.png` (1000x800 pixels)
- **Content**: 4-panel performance dashboard
- **Charts**: CPU Usage, Memory Usage, Disk I/O, Network Usage
- **Temporary**: Automatically deleted after email delivery

### Process Tracking

- **File**: `LoggingProcessID.txt`
- **Purpose**: Stores background monitoring process ID for clean termination

## Performance Considerations

### Optimizations

- **High Priority**: Monitoring process runs at high system priority
- **Efficient Collection**: 5-second intervals balance detail vs. overhead
- **Memory Management**: Automatic garbage collection before file operations
- **Retry Logic**: Robust error handling for file I/O operations

### Resource Usage

- **CPU Impact**: Minimal (~1-2% on modern systems)
- **Memory**: ~10-20MB for monitoring process
- **Disk Space**: 1MB log files + temporary chart files
- **Network**: Only during email transmission
