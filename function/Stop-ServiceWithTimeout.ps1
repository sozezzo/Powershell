<#
.SYNOPSIS
    Stops a Windows service gracefully, and forcefully kills the process if it fails to stop within a given timeout.

.DESCRIPTION
    This function attempts to stop a Windows service by name. If the service does not stop within the specified timeout period,
    the function will locate the service's process ID and attempt to kill it. It returns $true if the service is stopped at the end,
    and $false otherwise.

.PARAMETER ServiceName
    The name of the service to stop.

.PARAMETER TimeoutInSeconds
    The maximum time to wait for the service to stop gracefully before killing the process. Default is 30 seconds.

.EXAMPLE
    Stop-ServiceWithTimeout -ServiceName 'Spooler' -TimeoutInSeconds 15

    Attempts to stop the 'Spooler' service, waits up to 15 seconds, then kills the process if still running.

.OUTPUTS
    [bool] True if the service was stopped successfully; otherwise, false.

.NOTES
    Author: Milton Soz
    Created: 2025-06-25
    Version: 1.0
#>
function Stop-ServiceWithTimeout {
    param(
        [Parameter(Mandatory)]
        [string]$ServiceName,

        [int]$TimeoutInSeconds = 30
    )

    # Get the service object
    $service = Get-Service -Name $ServiceName -ErrorAction Stop

    # If already stopped, exit early
    if ($service.Status -eq 'Stopped') {
        Write-Output "Service '$ServiceName' is already stopped."
        return $true
    }

    # Attempt to stop the service gracefully
    Write-Output "Stopping service '$ServiceName'..."
    Stop-Service -Name $ServiceName -Force

    # Wait for service to stop, up to TimeoutInSeconds
    $elapsed = 0
    while ((Get-Service -Name $ServiceName).Status -ne 'Stopped' -and $elapsed -lt $TimeoutInSeconds) {
        Start-Sleep -Seconds 1
        $elapsed++
    }

    # If service has stopped, return success
    if ((Get-Service -Name $ServiceName).Status -eq 'Stopped') {
        Write-Output "Service '$ServiceName' stopped successfully."
        return $true
    }

    # If service did not stop, attempt to kill the associated process
    Write-Warning "Service '$ServiceName' did not stop within $TimeoutInSeconds seconds. Attempting to kill the process..."

    # Query WMI for the process ID of the service
    $query = "SELECT ProcessId FROM Win32_Service WHERE Name = '$ServiceName'"
    $processId = (Get-WmiObject -Query $query).ProcessId

    if ($processId -ne $null -and $processId -ne 0) {
        try {
            Stop-Process -Id $processId -Force -ErrorAction Stop
            Write-Output "Process $processId associated with service '$ServiceName' was killed."
        } catch {
            Write-Error "Failed to kill process ID ${processId}: $($_.Exception.Message)"
        }
    } else {
        Write-Warning "Could not find process ID for service '$ServiceName'."
    }

    # Perform a final status check after process termination
    Start-Sleep -Seconds 2
    $finalStatus = (Get-Service -Name $ServiceName).Status
    if ($finalStatus -eq 'Stopped') {
        return $true
    } else {
        Write-Warning "Service '$ServiceName' is still running after attempting to kill the process."
        return $false
    }
}
