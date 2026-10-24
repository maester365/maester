function Send-MtTelemetryRequest {
    <#
    .SYNOPSIS
    Starts one telemetry POST without waiting for it.

    .DESCRIPTION
    Write-Telemetry calls this for every event, so telemetry never holds up the command that sends it. The request
    runs in the background on one shared HttpClient with a 5-second timeout, and the task is kept until
    Wait-MtTelemetry gives the pending requests a short time to finish before the command returns. A failure is
    written to the verbose stream and never stops the command.

    .PARAMETER Uri
    The endpoint to post to.

    .PARAMETER Body
    The event, already serialised as JSON.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Uri,

        [Parameter(Mandatory = $true)]
        [string] $Body
    )

    try {
        if (-not $script:MtTelemetryClient) {
            $client = [System.Net.Http.HttpClient]::new()
            $client.Timeout = [timespan]::FromSeconds(5)
            $script:MtTelemetryClient = $client
        }
        if ($null -eq $script:MtTelemetryPending) { $script:MtTelemetryPending = [System.Collections.Generic.List[System.Threading.Tasks.Task]]::new() }
        $content = [System.Net.Http.StringContent]::new($Body, [System.Text.Encoding]::UTF8, 'application/json')
        $script:MtTelemetryPending.Add($script:MtTelemetryClient.PostAsync($Uri, $content))
    } catch {
        Write-Verbose "Telemetry was not sent: $($_.Exception.Message)"
    }
}
