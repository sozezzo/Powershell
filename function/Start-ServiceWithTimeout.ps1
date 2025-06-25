<#
.SYNOPSIS
    Starts a Windows service and waits until it is running or a timeout occurs.

.DESCRIPTION
    This function checks if a service is already running. If not, it attempts to start it
    and waits for it to reach the 'Running' state within a specified timeout.
    If the service fails to start in time, it returns $false.

.PARAMETER ServiceName
    The name of the service to start.

.PARAMETER TimeoutInSeconds
    The maximum time (in seconds) to wait for the service to reach 'Running' status.
    Default is 10 seconds.

.EXAMPLE
    Start-ServiceWithTimeout -ServiceName 'Spooler' -TimeoutInSeconds 15

.OUTPUTS
    [bool] True if the service is running at the end, otherwise false.

.NOTES
    Author: Milton Sozezzo
    Created: 2025-06-25
#>
function Start-ServiceWithTimeout {
    param(
        [Parameter(Mandatory)]
        [string]$ServiceName,

        [int]$TimeoutInSeconds = 10
    )

    try {
        $service = Get-Service -Name $ServiceName -ErrorAction Stop
    } catch {
        Write-Error "Service '$ServiceName' not found: $($_.Exception.Message)"
        return $false
    }

    # If already running, no action needed
    if ($service.Status -eq 'Running') {
        Write-Output "Service '$ServiceName' is already running."
        return $true
    }

    # Try to start the service
    Write-Output "Starting service '$ServiceName'..."
    try {
        Start-Service -Name $ServiceName -ErrorAction Stop
    } catch {
        Write-Error "Failed to start service '$ServiceName': $($_.Exception.Message)"
        return $false
    }

    # Wait for the service to reach 'Running' status
    $elapsed = 0
    while ((Get-Service -Name $ServiceName).Status -ne 'Running' -and $elapsed -lt $TimeoutInSeconds) {
        Start-Sleep -Seconds 1
        $elapsed++
    }

    # Final status check
    if ((Get-Service -Name $ServiceName).Status -eq 'Running') {
        Write-Output "Service '$ServiceName' started successfully."
        return $true
    } else {
        Write-Warning "Service '$ServiceName' did not start within $TimeoutInSeconds seconds."
        return $false
    }
}
