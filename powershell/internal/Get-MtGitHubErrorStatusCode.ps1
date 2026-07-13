function Get-MtGitHubErrorStatusCode {
    <#
    .SYNOPSIS
    Internal: Extracts an HTTP status code from a GitHub API ErrorRecord.

    .DESCRIPTION
    Returns the integer status code when the ErrorRecord includes an HTTP response, or
    $null for transport failures where no HTTP response was produced.
    #>
    param([Parameter(Mandatory)] $ErrorRecord)
    try {
        if ($ErrorRecord.Exception.Response -and $ErrorRecord.Exception.Response.StatusCode) {
            return [int]$ErrorRecord.Exception.Response.StatusCode
        }
    } catch {
        Write-Debug "Get-MtGitHubErrorStatusCode: $($_.Exception.Message)"
    }
    return $null
}
