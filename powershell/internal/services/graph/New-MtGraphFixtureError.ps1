function New-MtGraphFixtureError {
    <#
    .SYNOPSIS
    Internal: Builds the error that Graph replay throws for a recorded error response or a request with no fixture.

    .DESCRIPTION
    For a recorded error response (-Status, a 4xx such as 403 or 404) the error looks like the one
    Invoke-MgGraphRequest throws: an HttpResponseException whose Response carries the status code, with the error
    body in ErrorDetails. Checks that branch on $_.Exception.Response.StatusCode, or on Test-MtGraphNotFoundError,
    take the same branch in replay as against the tenant.

    For a request with no fixture (-Missing) the error names the request, the fixture set and the file that would
    answer it, so the fixture can be recorded or written. It never looks like a 404, so no check mistakes it for
    an object that does not exist.

    For a request that does not go through Maester's Graph transport (-Unsupported: Invoke-MgGraphRequest called
    directly, for example to download a report to a file) the error says that replay cannot answer it. Inside a
    native test, Enable-MtGraphFixture's stand-in for Invoke-MgGraphRequest skips the test with this message.

    .EXAMPLE
    New-MtGraphFixtureError -Status 403 -Body '{"error":{"code":"Authorization_RequestDenied"}}' -Uri 'v1.0/x'

    Returns an ErrorRecord with status code 403.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Status')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Creates an object in memory, changes no state.')]
    [OutputType([System.Management.Automation.ErrorRecord])]
    param(
        # The recorded HTTP status.
        [Parameter(Mandatory, ParameterSetName = 'Status')]
        [int] $Status,

        # The recorded error body.
        [Parameter(ParameterSetName = 'Status')]
        [AllowNull()]
        [AllowEmptyString()]
        [string] $Body,

        # The keys of the requests that have no fixture.
        [Parameter(Mandatory, ParameterSetName = 'Missing')]
        [string[]] $Missing,

        # The fixture set the requests were looked for in.
        [Parameter(ParameterSetName = 'Missing')]
        [string] $Folder,

        # The files that would answer the requests.
        [Parameter(ParameterSetName = 'Missing')]
        [string[]] $File,

        # The request bypassed the Graph transport and cannot be replayed.
        [Parameter(Mandatory, ParameterSetName = 'Unsupported')]
        [switch] $Unsupported,

        # The HTTP method of the request that bypassed the transport.
        [Parameter(ParameterSetName = 'Unsupported')]
        [string] $Method,

        # The request, for the error's target.
        [Parameter()]
        [string] $Uri
    )

    if ($PSCmdlet.ParameterSetName -eq 'Unsupported') {
        $message = "Graph replay cannot answer $Method $Uri`: it is sent with Invoke-MgGraphRequest directly, not through " +
        "Invoke-MtGraphRequest, so it is neither recorded nor replayed. The test does not run offline."
        $exception = [System.NotSupportedException]::new($message)
        return [System.Management.Automation.ErrorRecord]::new($exception, 'MtGraphFixtureUnsupported', [System.Management.Automation.ErrorCategory]::NotImplemented, $Uri)
    }

    if ($PSCmdlet.ParameterSetName -eq 'Missing') {
        $lines = for ($i = 0; $i -lt $Missing.Count; $i++) {
            $hint = if ($File -and $i -lt $File.Count) { " (file graph/$($File[$i]))" } else { '' }
            "  $($Missing[$i])$hint"
        }
        $message = "Graph replay has no fixture for this request in '$Folder':`n$($lines -join "`n")`n" +
        'Record it with Enable-MtGraphFixture -Mode Record against a test tenant, or write it with New-MtGraphFixture. ' +
        'Get-MtGraphFixtureStatus lists every request of the run that had no fixture.'
        $exception = [System.InvalidOperationException]::new($message)
        return [System.Management.Automation.ErrorRecord]::new($exception, 'MtGraphFixtureMissing', [System.Management.Automation.ErrorCategory]::ObjectNotFound, $Uri)
    }

    $statusCode = [System.Net.HttpStatusCode]$Status
    $code = $null
    $text = $null
    if ($Body) {
        try {
            $node = [System.Text.Json.Nodes.JsonNode]::Parse($Body)
            if ($null -ne $node['error']) {
                if ($null -ne $node['error']['code']) { $code = $node['error']['code'].GetValue[string]() }
                if ($null -ne $node['error']['message']) { $text = $node['error']['message'].GetValue[string]() }
            }
        } catch {
            Write-Debug "The recorded error body is not JSON: $_"
        }
    }
    # The first sentence is the one the Graph SDK writes; the rest says where the response came from.
    $message = "Response status code does not indicate success: $statusCode ($statusCode). Graph replay: $Uri"
    if ($code) { $message += " ($code)" }
    if ($text) { $message += ": $text" }

    $response = [System.Net.Http.HttpResponseMessage]::new($statusCode)
    if ($Body) { $response.Content = [System.Net.Http.StringContent]::new($Body, [System.Text.Encoding]::UTF8, 'application/json') }
    # The exception type of the Graph SDK, so the error is the one a check sees against the tenant.
    $sdkException = 'Microsoft.Graph.PowerShell.Authentication.Helpers.HttpResponseException' -as [type]
    $exception = if ($sdkException) {
        $sdkException::new($message, $response)
    } else {
        $fallback = [System.Net.Http.HttpRequestException]::new($message, $null, $statusCode)
        $fallback | Add-Member -MemberType NoteProperty -Name Response -Value $response -PassThru
    }
    # The error ID and category of the Graph SDK's own error.
    $record = [System.Management.Automation.ErrorRecord]::new($exception, 'InvokeGraphHttpResponseException', [System.Management.Automation.ErrorCategory]::InvalidOperation, $Uri)
    if ($Body) { $record.ErrorDetails = [System.Management.Automation.ErrorDetails]::new($Body) }
    return $record
}
