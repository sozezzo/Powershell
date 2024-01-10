function Send-TeamsMessage {
    Param(
        [string]$WebhookUrl,  # The Incoming Webhook URL of your Teams channel
        [string]$Message      # The message to be sent to the Teams channel
    )

    try {
        # Create the message payload
        $payload = @{
            text = $Message
        } | ConvertTo-Json

        # Headers for the POST request
        $headers = @{
            "Content-Type" = "application/json"
        }

        # Send POST request to the Teams webhook
        Invoke-RestMethod -Uri $WebhookUrl -Method Post -Body $payload -Headers $headers

        Write-Host "Message sent to Teams successfully."
    }
    catch {
        Write-Error "Failed to send message to Teams: $_"
    }
}

# Example usage
$webhookUrl = "https://outlook.office.com/webhook/your-webhook-url"  # Replace with your actual Webhook URL
$message = "Hello, this is a test message from PowerShell!"
Send-TeamsMessage -WebhookUrl $webhookUrl -Message $message
