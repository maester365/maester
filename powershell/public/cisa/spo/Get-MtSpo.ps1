<#
.SYNOPSIS
    Retrieves cached SPO tenant settings or requests from Get-SPOTenant

.DESCRIPTION
    Manages the SPO tenant settings caching. Calls Get-SPOTenant and caches the result
    to avoid redundant calls during a test session.

    Returns $null if the Microsoft.Online.SharePoint.PowerShell module is not loaded
    or if Connect-SPOService has not been called.

.EXAMPLE
    Get-MtSpo

    Returns the cached SPO tenant settings object

.LINK
    https://maester.dev/docs/commands/Get-MtSpo
#>
function Get-MtSpo {
    [CmdletBinding()]
    [OutputType([psobject])]
    param()

    if ($null -eq $__MtSession.SpoCache.SpoTenant) {
        Write-Verbose "SPO tenant settings not in cache, requesting."

        # Check if the SPO module is available
        if (-not (Get-Module -Name 'Microsoft.Online.SharePoint.PowerShell' -ErrorAction SilentlyContinue)) {
            Write-Verbose "Microsoft.Online.SharePoint.PowerShell module is not loaded."
            return $null
        }

        # Check if connected to SPO by attempting to get tenant settings
        try {
            $response = Get-SPOTenant -ErrorAction Stop
            $__MtSession.SpoCache.SpoTenant = $response
        } catch {
            Write-Verbose "Not connected to SharePoint Online or Get-SPOTenant failed: $($_.Exception.Message)"
            return $null
        }
    } else {
        Write-Verbose "SPO tenant settings in cache."
    }

    return $__MtSession.SpoCache.SpoTenant
}
