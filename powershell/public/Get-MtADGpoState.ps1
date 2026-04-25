function Get-MtADGpoState {
    <#
    .SYNOPSIS
    Collects Active Directory Group Policy state information.

    .DESCRIPTION
    Collects GPO data including GPO objects, reports, permissions, and SYSVOL data.
    Results are cached for the session to avoid repeated queries.

    .PARAMETER Refresh
    Forces a refresh of the data from Active Directory, bypassing the cache.

    .EXAMPLE
    Get-MtADGpoState

    Returns cached GPO state or collects if not already cached.

    .EXAMPLE
    Get-MtADGpoState -Refresh

    Forces a fresh collection of GPO state data from Active Directory.

    .LINK
    https://maester.dev/docs/commands/Get-MtADGpoState
    #>
    [CmdletBinding()]
    param(
        [switch]$Refresh
    )

    $cacheKey = 'GpoState'

    if ($Refresh -or -not $__MtSession.ADCache.ContainsKey($cacheKey)) {
        Write-Verbose 'Collecting AD GPO State data from Active Directory'

        try {
            $rootDSE = Get-ADRootDSE
            $configurationNC = $rootDSE.configurationNamingContext

            $gpoState = @{
                GPOs            = Get-GPO -All
                GPOLinks        = Get-ADObject -Filter * -SearchBase "CN=Sites,CN=Configuration,$configurationNC" -Properties gPLink
                SiteContainers  = Get-ADObject -Filter * -SearchBase "CN=Sites,CN=Configuration,$configurationNC" -Properties *
                CollectionTime  = Get-Date
            }

            $__MtSession.ADCache[$cacheKey] = $gpoState

            Write-Verbose "Successfully collected AD GPO State data at $($gpoState.CollectionTime)"
        }
        catch [Management.Automation.CommandNotFoundException] {
            Write-Error "The GroupPolicy or Active Directory module is not installed. Please install RSAT-AD-PowerShell and GPMC or run on a domain-joined machine."
            return $null
        }
        catch {
            Write-Error "Failed to collect AD GPO State data: $($_.Exception.Message)"
            return $null
        }
    }
    else {
        Write-Verbose 'Using cached AD GPO State data'
    }

    return $__MtSession.ADCache[$cacheKey]
}
