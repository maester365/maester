function Get-MtAssetTypeDefinition {
    <#
    .SYNOPSIS
    Returns the curated asset type catalog used to filter the asset inventory.

    .DESCRIPTION
    Single source of truth for which object types count as an "asset".

    KnownTypes lists the systems whose Type values are a curated, enumerable set. A record of
    such a system whose Type is not listed is dropped by Get-MtAssetInventory and reported in a
    warning, so a new type is noticed and added here instead of silently reaching the report.

    Systems that are not listed in KnownTypes (MicrosoftGraph, ...) are pass-through: their Type
    is the Graph resource path, which is unbounded and cannot be enumerated.

    ExcludedTypes lists types that are recognised but are deliberately not inventoried — report
    findings and alerts describe a condition, not an addressable object. They are dropped
    without a warning.

    .EXAMPLE
    (Get-MtAssetTypeDefinition).KnownTypes.EntraID

    Lists the Entra ID object types that are inventoried as assets.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    return @{
        KnownTypes    = @{
            EntraID        = @(
                'AccessPackage'
                'AccessPackageCatalog'
                'AppRegistration'
                'AuthenticationMethod'
                'AuthorizationPolicy'
                'ConditionalAccessPolicy'
                'ConsentPolicy'
                'Device'
                'DirectoryRole'
                'Domains'
                'Group'
                'ServicePrincipal'
                'User'
            )
            DefenderXDR    = @(
                'Device'
            )
            ExchangeOnline = @(
                'SharingPolicy'
                'TransportRule'
            )
            GitHub         = @(
                'GitHubOrganization'
                'GitHubRepository'
                'GitHubResource'
            )
        }
        ExcludedTypes = @{
            # Entra recommendations and PIM alerts are findings about the tenant, not objects in it.
            EntraID = @(
                'EntraRecommendation'
                'PimAlert'
            )
        }
    }
}
