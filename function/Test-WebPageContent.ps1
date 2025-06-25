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

    $endTime = (Get-Date).AddSeconds($TimeoutInSeconds)

    while ((Get-Date) -lt $endTime) {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

        if (Test-WebPageContent -Url $Url -Port $Port -StringToVerify $StringToVerify) {
            Write-Host "$timestamp - ✅ Success: '${StringToVerify}' found at ${Url}:${Port}."
            return $true
        }

        Write-Host "$timestamp - ❌ Fail: '${StringToVerify}' not found at ${Url}:${Port}. Retrying in $CheckInterval seconds..."
        Start-Sleep -Seconds $CheckInterval
    }

    Write-Host "$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - ⏱ Timeout reached. '${StringToVerify}' not found at ${Url}:${Port}."
    return $false
}
