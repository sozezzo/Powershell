<#
.SYNOPSIS
    Checks a web page for a specific string and waits until it appears or a timeout occurs.

.DESCRIPTION
    This script defines two PowerShell functions:
    1. Test-WebPageContent: Sends an HTTP request to a given URL and port, and checks if a specific string is present in the response.
    2. Wait-ForWebPageContent: Repeatedly calls Test-WebPageContent every N seconds until the string is found or a timeout is reached.

.PARAMETER Url
    The base URL of the target web server (e.g., http://localhost or http://10.0.0.1).

.PARAMETER Port
    The port to connect to on the web server.

.PARAMETER StringToVerify
    The string to look for in the web page content.

.PARAMETER TimeoutInSeconds
    (Optional) Maximum wait time in seconds before giving up. Default is 300 seconds (5 minutes).

.PARAMETER CheckInterval
    (Optional) Time interval in seconds between each check. Default is 30 seconds.

.EXAMPLE
    Wait-ForWebPageContent -Url "http://10.140.59.206" -Port 7777 -StringToVerify "Connect" -TimeoutInSeconds 60 -CheckInterval 10

    This will check every 10 seconds for up to 60 seconds if the string "Connect" appears in the content of http://10.140.59.206:7777.
#>

function Test-WebPageContent {
    param(
        [Parameter(Mandatory)]
        [string]$Url,

        [Parameter(Mandatory)]
        [int]$Port,

        [Parameter(Mandatory)]
        [string]$StringToVerify
    )

    try {
        # Build full URI
        $uri = [Uri]::new("${Url}:$Port")

        # Attempt to get the page content with a timeout
        $response = Invoke-WebRequest -Uri $uri -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop

        # Return false if status code is not OK (200)
        if ($response.StatusCode -ne 200) {
            return $false
        }

        # Return true if the expected string is found, otherwise false
        if ($response.Content -notmatch [Regex]::Escape($StringToVerify)) {
            return $false
        }

        return $true
    }
    catch {
        # Handle common connection-related web exceptions
        if ($_.Exception -is [System.Net.WebException]) {
            $webEx = $_.Exception
            if ($webEx.Status -in @(
                [System.Net.WebExceptionStatus]::ConnectFailure,
                [System.Net.WebExceptionStatus]::Timeout,
                [System.Net.WebExceptionStatus]::NameResolutionFailure,
                [System.Net.WebExceptionStatus]::ProtocolError
            )) {
                return $false
            }
        }
        return $false
    }
}



<#
.SYNOPSIS
    Waits for a specific string to appear in the content of a web page.

.DESCRIPTION
    This function repeatedly checks the content of a specified web page at a given port,
    searching for a specific string. It continues to check at defined intervals until the string
    is found or a timeout is reached.

.PARAMETER Url
    The base URL (e.g., http://localhost or http://10.0.0.1) to check.

.PARAMETER Port
    The port number the web page is served on (e.g., 80 or 8080).

.PARAMETER StringToVerify
    The string that must be present in the web page's content to consider the check successful.

.PARAMETER TimeoutInSeconds
    Total duration (in seconds) to wait for the string to appear. Default is 300 seconds (5 minutes).

.PARAMETER CheckInterval
    Interval (in seconds) between each check attempt. Default is 30 seconds.

.OUTPUTS
    Returns $true if the string is found within the timeout.
    Returns $false if the timeout is reached without finding the string.

.EXAMPLE
    Wait-ForWebPageContent -Url "http://localhost" -Port 8080 -StringToVerify "Server Ready" -TimeoutInSeconds 120 -CheckInterval 10

    Checks every 10 seconds for up to 2 minutes whether "Server Ready" appears on http://localhost:8080.
#>

function Wait-ForWebPageContent {
    param(
        [Parameter(Mandatory)]
        [string]$Url,

        [Parameter(Mandatory)]
        [int]$Port,

        [Parameter(Mandatory)]
        [string]$StringToVerify,

        [int]$TimeoutInSeconds = 300,    # Default timeout: 5 minutes
        [int]$CheckInterval = 30         # Default interval: 30 seconds
    )

    # Calculate the time at which to stop checking
    $endTime = (Get-Date).AddSeconds($TimeoutInSeconds)

    while ((Get-Date) -lt $endTime) {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

        # Call the test function to check if the expected string is present
        if (Test-WebPageContent -Url $Url -Port $Port -StringToVerify $StringToVerify) {
            Write-Host "$timestamp - ✅ Success: '${StringToVerify}' found at ${Url}:${Port}."
            return $true
        }

        # If not found, wait and retry
        Write-Host "$timestamp - ❌ Fail: '${StringToVerify}' not found at ${Url}:${Port}. Retrying in $CheckInterval seconds..."
        Start-Sleep -Seconds $CheckInterval
    }

    # Timeout reached without success
    Write-Host "$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - ⏱ Timeout reached. '${StringToVerify}' not found at ${Url}:${Port}."
    return $false
}
