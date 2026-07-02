function Get-MtGitHubErrorStatusCode {
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
