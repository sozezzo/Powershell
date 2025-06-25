function Send-HtmlEmail {
    <#
    .SYNOPSIS
    Sends an HTML-formatted email with footer info (script name, server name, timestamp).

    .PARAMETER To
    Recipient email address(es).

    .PARAMETER From
    Sender email address.

    .PARAMETER Subject
    Subject of the email.

    .PARAMETER Body
    HTML-formatted body content (excluding footer).

    .PARAMETER SmtpServer
    SMTP server to use.

    .PARAMETER SmtpPort
    (Optional) SMTP server port. Default is 25.

    .PARAMETER UseSsl
    (Optional) Whether to use SSL. Default is $false.

    .PARAMETER Credential
    (Optional) PSCredential object for authenticated SMTP.

    .EXAMPLE
    Send-HtmlEmail -To "user@example.com" -From "me@example.com" -Subject "Report" `
        -Body "<h2>Status Report</h2><p>All systems operational.</p>" `
        -SmtpServer "smtp.example.com"
    #>

    param (
        [Parameter(Mandatory)] [string[]] $To,
        [Parameter(Mandatory)] [string] $From,
        [Parameter(Mandatory)] [string] $Subject,
        [Parameter(Mandatory)] [string] $Body,
        [Parameter(Mandatory)] [string] $SmtpServer,
        [int] $SmtpPort = 25,
        [switch] $UseSsl,
        [System.Management.Automation.PSCredential] $Credential = $null
    )

    try {
        # Footer info
        # Get script file name if running from a script, otherwise use function name
        $scriptName = if ($PSCommandPath) {
            Split-Path $PSCommandPath -Leaf
        } else {
            $MyInvocation.ScriptName
        }

        $serverName = $env:COMPUTERNAME
        $timestamp  = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")

        $footer = @"
<hr>
<p style='font-size:small;color:gray'>
    Script: <strong>$scriptName</strong><br>
    Server: <strong>$serverName</strong><br>
    Sent: <strong>$timestamp</strong>
</p>
"@

        $finalBody = "$Body$footer"

        $mailParams = @{
            To         = $To
            From       = $From
            Subject    = $Subject
            Body       = $finalBody
            BodyAsHtml = $true
            SmtpServer = $SmtpServer
            Port       = $SmtpPort
            UseSsl     = $UseSsl.IsPresent
        }

        if ($Credential) {
            $mailParams.Credential = $Credential
        }

        Send-MailMessage @mailParams -ErrorAction Stop

        Write-Output "✅ Email sent to: $($To -join ', ')"
        return $true
    } catch {
        Write-Warning "❌ Failed to send email: $_"
        return $false
    }
}
