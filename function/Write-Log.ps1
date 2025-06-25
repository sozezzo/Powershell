<#
.SYNOPSIS
    Writes timestamped log messages to a primary log file and optional level-specific log files.

.DESCRIPTION
    This function appends timestamped log messages to a specified log file.
    If the log file exceeds the defined size limit, it is rotated to a `.bak` file.
    It also supports writing to additional log files categorized by log level (Info, Warning, Error, Alert, Important).
    When the -Verbose switch is used, messages are printed to the console with color based on severity.

.PARAMETER Message
    The log message to write.

.PARAMETER LogFileName
    The path to the main log file. If omitted, defaults to the current script path with `.log` extension.

.PARAMETER MaximumSizeLogKB
    The maximum size of the log file in kilobytes before it is rotated. Default is 10,000 KB (10 MB).

.PARAMETER Level
    Optional severity level of the log entry. If specified, the log is also written to a second file with the format: `<LogFileName>.<Level>.log`.

.PARAMETER Verbose
    If specified, prints the log message to the console. The message is color-coded based on the severity level.

.EXAMPLE
    Write-Log -Message "Backup completed" -LogFileName "C:\Logs\backup.log" -Level Info -Verbose

.NOTES
    Author: Milton Soz
    License: MIT
    Version: 1.0
    GitHub: https://github.com/<your-username>/<your-repo-name>

#>

function Write-Log {
    param(
        [string] $Message = "",
        [string] $LogFileName = "",
        [int] $MaximumSizeLogKB = 10000,
        [ValidateSet("Info", "Warning", "Error", "Alert", "Important")]
        [string] $Level,
        [switch] $Verbose
    )

    if ([string]::IsNullOrWhiteSpace($LogFileName)) {
        $LogFileName = "$PSCommandPath.log"
    }

    $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logEntry = "$ts|$Message"

    # Rotate base log file if needed
    if (Test-Path $LogFileName) {
        $SizeLogKB = (Get-Item $LogFileName).Length / 1KB
        if ($SizeLogKB -gt $MaximumSizeLogKB) {
            $LogFileBak = "$LogFileName.bak"
            if (Test-Path $LogFileBak) {
                Remove-Item -Force $LogFileBak
            }
            Rename-Item -Path $LogFileName -NewName $LogFileBak
        }
    }

    # Always write to main log file
    $logEntry | Tee-Object -FilePath $LogFileName -Append | Out-Null

    # If level specified, write to separate log file
    if ($Level) {
        $levelFile = "$LogFileName.$Level.log"
        if (Test-Path $levelFile) {
            $SizeLogKB = (Get-Item $levelFile).Length / 1KB
            if ($SizeLogKB -gt $MaximumSizeLogKB) {
                $levelFileBak = "$levelFile.bak"
                if (Test-Path $levelFileBak) {
                    Remove-Item -Force $levelFileBak
                }
                Rename-Item -Path $levelFile -NewName $levelFileBak
            }
        }

        $logEntry | Tee-Object -FilePath $levelFile -Append | Out-Null
    }

    if ($Verbose) {
        $color = switch ($Level) {
            "Info"      { "Gray" }
            "Warning"   { "Yellow" }
            "Error"     { "Red" }
            "Alert"     { "Magenta" }
            "Important" { "Cyan" }
            default     { "White" }
        }
        Write-Host $logEntry -ForegroundColor $color
    }
}
