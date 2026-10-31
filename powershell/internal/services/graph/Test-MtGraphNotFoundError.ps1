function Test-MtGraphNotFoundError {
    <#
    .SYNOPSIS
    Internal: Returns whether a Microsoft Graph ErrorRecord is a 404 Not Found.

    .DESCRIPTION
    Checks the response status code in its enum, string and integer forms, then the exception's own StatusCode
    property, then the message, because the form depends on the Graph SDK and PowerShell version.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # The ErrorRecord caught from a Graph request.
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.ErrorRecord]$ErrorRecord
    )

    $responseStatusCode = $ErrorRecord.Exception.Response.StatusCode
    $exceptionStatusCode = $ErrorRecord.Exception.StatusCode
    return ($responseStatusCode -eq [System.Net.HttpStatusCode]::NotFound) -or
        ($responseStatusCode -eq 'NotFound') -or
        ($responseStatusCode -eq 404) -or
        ($exceptionStatusCode -eq [System.Net.HttpStatusCode]::NotFound) -or
        ($ErrorRecord.Exception.Message -match 'NotFound|404')
}
