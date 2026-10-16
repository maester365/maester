function ConvertTo-MtAffectedObjectRecord {
    <#
    .SYNOPSIS
    Converts Graph objects passed to Add-MtTestResultDetail into normalized affected objects records.

    .DESCRIPTION
    Produces one record per Graph object with a stable schema:
    System / AnchorKind / Type / Id / DisplayName / PortalLink / Source.

    AnchorKind is 'Instance' when the object has its own portal deep link,
    'Surface' when the type only maps to a tenant-level settings page.
    Objects of unknown type still yield a record (AnchorKind 'Instance' when an id
    is present) so no referenced entity is silently dropped.
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        # Collection of Graph objects referenced by a test result.
        [Parameter(Mandatory = $true)]
        [Object[]] $GraphObjects,

        # The declared GraphObjectType. If empty, the type is inferred per object from @odata.type.
        [Parameter(Mandatory = $false)]
        [string] $GraphObjectType
    )

    $portalLinkTemplate = Get-MtPortalLinkTemplate

    # GraphObjectType → canonical object type. Must match the type names emitted by
    # Get-MtAffectedObjectFromMarkdown so records from both sources dedupe correctly.
    $canonicalType = @{
        ConditionalAccess = 'ConditionalAccessPolicy'
        Users             = 'User'
        UserRole          = 'User'
        Groups            = 'Group'
        Devices           = 'Device'
    }

    # GraphObjectType whose objects are really another type: the check links to a settings blade
    # but passes the affected objects. IdentityProtection results are the users at risk.
    $objectTypeAlias = @{
        IdentityProtection = 'Users'
    }

    # Kept out of Get-MtPortalLinkTemplate: Get-GraphObjectMarkdown would render these types without a link.
    # Applications are absent because markdown deep links identify them by appId, not object id.
    $odataObjectType = @{
        '#microsoft.graph.servicePrincipal'        = 'ServicePrincipal'
        '#microsoft.graph.directoryRole'           = 'DirectoryRole'
        '#microsoft.graph.conditionalAccessPolicy' = 'ConditionalAccessPolicy'
    }

    $records = foreach ($item in $GraphObjects) {
        $id = Get-ObjectProperty $item 'id'
        $displayName = Get-ObjectProperty $item 'displayName'
        $userPrincipalName = Get-ObjectProperty $item 'userPrincipalName'
        if ([string]::IsNullOrWhiteSpace($displayName) -and $GraphObjectType -eq 'Users') {
            $displayName = $userPrincipalName
        }
        $odataType = Get-ObjectProperty $item '@odata.type'

        $type = $GraphObjectType
        if (-not $type -and $odataType -and $portalLinkTemplate.OdataTypeMapping.ContainsKey($odataType)) {
            $type = $portalLinkTemplate.OdataTypeMapping[$odataType]
        }
        if ($type -and $objectTypeAlias.ContainsKey($type)) {
            $type = $objectTypeAlias[$type]
        }

        $portalLink = $null
        if ($type -and $portalLinkTemplate.LinkTemplates.ContainsKey($type)) {
            $template = $portalLinkTemplate.LinkTemplates[$type]
            # A per-object template without the id would open a broken blade.
            if ($id -or -not $template.Contains('{0}')) {
                $portalLink = $template -f $id
            }
        }

        if ($type -and $portalLinkTemplate.InstanceTypes -contains $type) {
            # Without an id the object is not addressable, and every id-less record would merge into one object.
            $anchorKind = if ($id) { 'Instance' } else { 'Unknown' }
        } elseif ($type) {
            $anchorKind = 'Surface'
        } elseif ($id) {
            $anchorKind = 'Instance'
        } else {
            $anchorKind = 'Unknown'
        }

        [PSCustomObject]@{
            System            = 'EntraID'
            AnchorKind        = $anchorKind
            Type              = if ($type -and $canonicalType.ContainsKey($type)) { $canonicalType[$type] }
            elseif ($type) { $type }
            elseif ($odataType -and $odataObjectType.ContainsKey($odataType)) { $odataObjectType[$odataType] }
            elseif ($odataType) { $odataType }
            else { 'Unknown' }
            Id                = $id
            DisplayName       = $displayName
            UserPrincipalName = $userPrincipalName
            PortalLink        = $portalLink
            Source            = 'GraphObjects'
        }
    }
    return @($records)
}
