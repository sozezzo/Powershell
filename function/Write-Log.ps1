<#
.SYNOPSIS
    Writes timestamped log messages to a primary log file and optional level-specific log files.

.DESCRIPTION
    - If no LogFileName is provided (and no global default is set), messages are NOT written to disk;
      they are printed to the console (as if -Verbose were used).
    - Supports global defaults:
        $Global:WriteLog_LogFileName      (string)  -> default log file path
        $Global:WriteLog_Verbose          (bool)    -> force console output
        $Global:WriteLog_MaximumSizeLogKB (int)     -> default rotation size in KB

.PARAMETER Message
    The log message to write.

.PARAMETER LogFileName
    The path to the main log file. If omitted and no global default exists, logs only to console.

.PARAMETER MaximumSizeLogKB
    The maximum size of the log file in kilobytes before it is rotated. Default is 50,000 KB (50 MB),
    unless overridden by $Global:WriteLog_MaximumSizeLogKB.

.PARAMETER Level
    Optional severity level of the log entry (Info, Warning, Error, Alert, Important).
    If specified, also writes to <LogFileName>.<Level>.log.

.PARAMETER Verbose
    If specified, prints the log message to the console (color-coded).

.EXAMPLE
    # Use only console (no file)
    Write-Log -Message "Backup completed" -Level Info -Verbose

.EXAMPLE
    # Use global defaults
    $Global:WriteLog_LogFileName      = 'C:\Logs\backup.log'
    $Global:WriteLog_Verbose          = $true
    $Global:WriteLog_MaximumSizeLogKB = 20000
    Write-Log -Message "Backup completed" -Level Info

.NOTES
    Author: Milton Soz
    License: MIT
    Version: 1.1
#>

function Write-Log {
    param(
        [string] $Message = "",
        [string] $LogFileName = "",
        [int]    $MaximumSizeLogKB = 50000,
        [ValidateSet("Info", "Warning", "Error", "Alert", "Important")]
        [string] $Level,
        [switch] $Verbose
    )

    # ----- Resolve effective settings (Params > Globals > Defaults) -----
    # LogFileName: if parameter empty/null, fall back to global; otherwise console-only if still empty
    $effectiveLogFile = if ($PSBoundParameters.ContainsKey('LogFileName') -and -not [string]::IsNullOrWhiteSpace($LogFileName)) {
        $LogFileName
    } elseif ($Global:WriteLog_LogFileName -and -not [string]::IsNullOrWhiteSpace($Global:WriteLog_LogFileName)) {
        [string]$Global:WriteLog_LogFileName
    } else {
        ""  # console-only mode
    }

    # MaximumSizeLogKB: param wins, else global, else default (param default already 50000)
    if (-not $PSBoundParameters.ContainsKey('MaximumSizeLogKB') -and $Global:WriteLog_MaximumSizeLogKB) {
        $MaximumSizeLogKB = [int]$Global:WriteLog_MaximumSizeLogKB
    }

    # Verbose: param OR global
    $effectiveVerbose =
        ($Verbose.IsPresent) -or
        ([bool]($Global:WriteLog_Verbose) -eq $true) -or
        ([string]::IsNullOrWhiteSpace($effectiveLogFile))  # console-only if no file name

    # ----- Compose entry -----
    $ts       = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logEntry = "$ts|$Message"

    # ----- Write to files if we have a file path -----
    if (-not [string]::IsNullOrWhiteSpace($effectiveLogFile)) {

        # Rotate base log file if needed
        if (Test-Path $effectiveLogFile) {
            $SizeLogKB = (Get-Item $effectiveLogFile).Length / 1KB
            if ($SizeLogKB -gt $MaximumSizeLogKB) {
                $LogFileBak = "$effectiveLogFile.bak"
                if (Test-Path $LogFileBak) { Remove-Item -Force $LogFileBak }
                Rename-Item -Path $effectiveLogFile -NewName $LogFileBak
            }
        } else {
            # Ensure the folder exists if a path was provided
            $dir = Split-Path -Path $effectiveLogFile -Parent
            if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        }

        # Write to main log file
        $logEntry | Tee-Object -FilePath $effectiveLogFile -Append | Out-Null

        # If level specified, write to separate log file and rotate if needed
        if ($Level) {
            $levelFile = "$effectiveLogFile.$Level.log"
            if (Test-Path $levelFile) {
                $SizeLogKB = (Get-Item $levelFile).Length / 1KB
                if ($SizeLogKB -gt $MaximumSizeLogKB) {
                    $levelFileBak = "$levelFile.bak"
                    if (Test-Path $levelFileBak) { Remove-Item -Force $levelFileBak }
                    Rename-Item -Path $levelFile -NewName $levelFileBak
                }
            }
            $logEntry | Tee-Object -FilePath $levelFile -Append | Out-Null
        }
    }

    # ----- Console output if verbose or console-only mode -----
    if ($effectiveVerbose) {
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
