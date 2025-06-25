
<#
.SYNOPSIS
    Waits for a web page to respond and (optionally) contain a specific string.

.DESCRIPTION
    Repeatedly performs HTTP requests to a URL and port combination, at defined intervals,
    until it receives HTTP 200 and (optionally) the expected string in the response content.
    If the string is found or page responds successfully within timeout, returns $true.
    Otherwise, returns $false when timeout is reached.

.PARAMETER Url
    The base URL (e.g., http://localhost or http://10.0.0.1).

.PARAMETER Port
    The port number the server is listening on.

.PARAMETER StringToVerify
    (Optional) If specified, the function will check that the page content contains this string.

.PARAMETER TimeoutInSeconds
    Maximum time (in seconds) to wait for a valid response. Default is 300.

.PARAMETER CheckInterval
    Time (in seconds) to wait between checks. Default is 30.

.EXAMPLE
    Wait-ForWebPageContent -Url "http://localhost" -Port 8080 -StringToVerify "Ready" -TimeoutInSeconds 120 -CheckInterval 10
#>

function Wait-ForWebPageContent {
    param(
        [Parameter(Mandatory)]
        [string]$Url,

        [Parameter(Mandatory)]
        [int]$Port,

        [string]$StringToVerify,         # optional

        [int]$TimeoutInSeconds = 300,    # Default timeout: 5 minutes
        [int]$CheckInterval = 30         # Default interval: 30 seconds
    )

    $endTime = (Get-Date).AddSeconds($TimeoutInSeconds)
    $uri = "${Url}:${Port}"

    while ((Get-Date) -lt $endTime) {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $info = ""

        try {
            $response = Invoke-WebRequest -Uri $uri -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop

            if ($response.StatusCode -eq 200) {
                if ([string]::IsNullOrWhiteSpace($StringToVerify) -or ($response.Content -match [Regex]::Escape($StringToVerify))) {
                    if (-not [string]::IsNullOrWhiteSpace($StringToVerify)) {
                        $info = "✅ Success: '${StringToVerify}' found at "
                    }
                    Write-Host "$timestamp --${info}${Url}:${Port}."
                    return $true
                }
            }

            if (-not [string]::IsNullOrWhiteSpace($StringToVerify)) {
                $info = "❌ Fail: '${StringToVerify}' not found at "
            } else {
                $info = "❌ HTTP 200 OK received, but required string not specified or not found at "
            }
        }
        catch {
            $info = "❌ Request failed at "
        }

        Write-Host "$timestamp -${info}${Url}:${Port}. Retrying in $CheckInterval seconds..."
        Start-Sleep -Seconds $CheckInterval
    }

    # Timeout reached without success
    $finalMessage = "$(Get-Date -Format "yyyy-MM-dd HH:mm:ss") - ⏱ Timeout reached. "
    if (-not [string]::IsNullOrWhiteSpace($StringToVerify)) {
        $finalMessage += "'${StringToVerify}' not found at ${Url}:${Port}."
    } else {
        $finalMessage += "No successful response from ${Url}:${Port}."
    }

    Write-Host $finalMessage
    return $false
}
