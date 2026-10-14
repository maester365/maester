function Get-AzdoAdvancedSecurityEnablement {
    <#
    .SYNOPSIS
    Returns the Azure DevOps Advanced Security organization enablement state.

    .DESCRIPTION
    Calls the Advanced Security org enablement API at api-version 7.2-preview.3, which is the earliest version
    that reports the separate GitHub Secret Protection and GitHub Code Security plans. Get-ADOPSOrganizationAdvancedSecurity
    pins 7.2-preview.1, which returns only the bundled enableOnCreate and advSecEnabled values, so it cannot be
    used for the per-plan checks. See https://github.com/AZDOPS/AZDOPS/issues/266.

    The request is not allowed to throw, because several checks share it and each needs to report the failure as
    a skipped test rather than an error. The returned object therefore carries either Enablement or RequestError,
    and the caller decides how to report it. Reporting is left to the caller so that Add-MtTestResultDetail
    resolves the companion markdown of the test that is running, not of this helper.

    .EXAMPLE
    Get-AzdoAdvancedSecurityEnablement -Organization 'contoso'

    Returns an object whose Enablement property holds the org enablement state, or whose RequestError property
    holds the terminating error if the call failed.

    .EXAMPLE
    Get-AzdoAdvancedSecurityEnablement -Organization 'contoso' -IncludeAllProperties

    Also requests the properties that are only returned on demand, such as per-repository blockPushes.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        # The Azure DevOps organization to query.
        [Parameter(Mandatory)]
        [string]$Organization,

        # Request the properties the API only returns when asked, currently per-repository blockPushes.
        [Parameter()]
        [switch]$IncludeAllProperties
    )

    $Query = if ($IncludeAllProperties) { 'includeAllProperties=true&api-version=7.2-preview.3' } else { 'api-version=7.2-preview.3' }
    $Uri = "https://advsec.dev.azure.com/$Organization/_apis/management/enablement?$Query"

    $Enablement = $null
    $RequestError = $null
    try {
        $Enablement = Invoke-ADOPSRestMethod -Uri $Uri -Method Get
    } catch {
        $RequestError = $_
        Write-Verbose "Failed to read Advanced Security enablement for '$Organization': $($_.Exception.Message)"
    }

    return [PSCustomObject]@{
        Enablement   = $Enablement
        RequestError = $RequestError
    }
}
