<#
.SCRIPT NAME
    Send-HtmlEmail.ps1

.AUTHOR
    Milton Sozezzo

.LICENSE
    MIT License (or specify another license)

.VERSION
    1.0

.DESCRIPTION
    Sends an HTML-formatted email using PowerShell's Send-MailMessage.
    Appends an automatic footer to the message with:
        - Script file name
        - Server/host name
        - Current timestamp

.PARAMETER To
    [string[]] One or more recipient email addresses.

.PARAMETER From
    [string] The sender's email address.

.PARAMETER Subject
    [string] Subject line of the email.

.PARAMETER Body
    [string] HTML content for the body of the email (excluding the footer).

.PARAMETER SmtpServer
    [string] The SMTP server address used to send the message.

.PARAMETER SmtpPort
    [int] (Optional) The SMTP server port number. Default is 25.

.PARAMETER UseSsl
    [switch] (Optional) If specified, the connection will use SSL.

.PARAMETER Credential
    [PSCredential] (Optional) A credential object for authenticated SMTP servers.
    If not provided, anonymous SMTP will be attempted.

.EXAMPLE
    Send-HtmlEmail -To "admin@example.com" -From "noreply@example.com" -Subject "Alert" `
        -Body "<h1>System Status</h1><p>Everything is operational.</p>" `
        -SmtpServer "smtp.example.com"

.NOTES
    Designed for automation scripts, monitoring tools, and scheduled jobs.
    Requires PowerShell 5.1+ or equivalent with access to Send-MailMessage.

.LAST UPDATED
    2025-06-25
#>

function Send-HtmlEmail {
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
