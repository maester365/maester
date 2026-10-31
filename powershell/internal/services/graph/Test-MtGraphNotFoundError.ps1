function Test-MtGraphNotFoundError {
    <#
    .SYNOPSIS
    Internal: Returns whether a Microsoft Graph ErrorRecord is a 404 Not Found.

    .DESCRIPTION
    Checks the response status code in its enum, string and integer forms, then the exception's own StatusCode
    property, on the exception and its inner exception, because the form depends on the Graph SDK and PowerShell
    version. When no status code is available it falls back to the Graph error code (Request_ResourceNotFound,
    ResourceNotFound) or a "Not Found" status in the message. A bare "404" in the message is not enough: object ids
    and Retry-After values can contain it.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # The ErrorRecord caught from a Graph request.
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.ErrorRecord]$ErrorRecord
    )

    $exceptions = @($ErrorRecord.Exception, $ErrorRecord.Exception.InnerException) | Where-Object { $null -ne $_ }
    $statusCodes = foreach ($exception in $exceptions) {
        if ($exception.PSObject.Properties['Response'] -and $null -ne $exception.Response) { $exception.Response.StatusCode }
        if ($exception.PSObject.Properties['StatusCode']) { $exception.StatusCode }
    }
    $statusCodes = @($statusCodes | Where-Object { $null -ne $_ })
    if ($statusCodes.Count -gt 0) {
        # Compared as text: an enum becomes 'NotFound', an integer '404', and a string status never fails to convert.
        return [bool]($statusCodes | Where-Object { "$_" -in 'NotFound', '404' })
    }

    $text = (@($ErrorRecord.ErrorDetails.Message) + @($exceptions | ForEach-Object Message)) -join "`n"
    return $text -match '\b(Request_)?ResourceNotFound\b|\(Not ?Found\)|\b404 \(?Not ?Found\)?'
}
