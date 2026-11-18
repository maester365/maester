function Get-MtEntraHardDeletionObjectStatus {
    <#
    .SYNOPSIS
    Returns the Hard Deletion Protection status of one object listed in the Maester config.

    .DESCRIPTION
    Reads the object from Microsoft Graph beta. Status is 'Protected', 'Not protected',
    'Soft deleted' or 'Not found'.

    When the active lookup returns HTTP 404, the function reads the object through the
    documented single-item route, directory/deletedItems/{id}, and checks that its @odata.type is
    the configured type or one of its Agent ID subtypes: agentUser for User,
    agentIdentityBlueprint for Application, and agentIdentity or
    agentIdentityBlueprintPrincipal for ServicePrincipal.

    It reports 'Soft deleted' when it finds the object there, whether or not the object has
    protection. An object of another type, a response without an @odata.type, or no object
    gives 'Not found'. Any Graph error other than a 404 is thrown.

    The Id must be the object ID, a GUID. The function uses its canonical lower-case form in both
    requests and in the result, so the result matches the objects that
    Get-MtEntraHardDeletionProtectedObject returns.

    .PARAMETER Configured
    A HardDeletionProtectedObjects entry with Type and Id.

    .EXAMPLE
    Get-MtEntraHardDeletionObjectStatus -Configured $Entry
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [object] $Configured
    )

    # GraphTypes are the @odata.type values a deleted object of this type can have. Agent ID objects
    # are covered through their underlying user, application and service principal types.
    $EndpointByType = @{
        user             = @{
            Name = 'User'; Path = 'users'; GraphTypes = @('user', 'agentUser')
        }
        group            = @{ Name = 'Group'; Path = 'groups'; GraphTypes = @('group') }
        application      = @{
            Name = 'Application'; Path = 'applications'
            GraphTypes = @('application', 'agentIdentityBlueprint')
        }
        serviceprincipal = @{
            Name = 'ServicePrincipal'; Path = 'servicePrincipals'
            GraphTypes = @(
                'servicePrincipal', 'agentIdentity', 'agentIdentityBlueprintPrincipal'
            )
        }
    }

    $Type = ([string]$Configured.Type).ToLowerInvariant()
    $ParsedId = [guid]::Empty
    $IdIsGuid = [guid]::TryParse([string]$Configured.Id, [ref]$ParsedId)
    if (!$EndpointByType.ContainsKey($Type) -or !$IdIsGuid) {
        throw (
            "Invalid HardDeletionProtectedObjects entry (Type '$($Configured.Type)', " +
            "Id '$($Configured.Id)'). Type must be User, Group, Application or " +
            'ServicePrincipal and Id must be the object ID (a GUID).'
        )
    }
    $Endpoint = $EndpointByType[$Type]
    $AcceptedTypes = @($Endpoint.GraphTypes | ForEach-Object { "#microsoft.graph.$_" })
    $Id = $ParsedId.ToString()

    $Object = $null
    $Status = 'Not found'
    try {
        $Object = Invoke-MtGraphRequest -ApiVersion 'beta' -RelativeUri "$($Endpoint.Path)/$Id" `
            -Select @('id', 'displayName', 'isHardDeleteProtectionEnabled') -ErrorAction Stop
        $Status = if ($Object.isHardDeleteProtectionEnabled -eq $true) {
            'Protected'
        } else {
            'Not protected'
        }
    } catch {
        if (!(Test-MtGraphNotFoundError -ErrorRecord $_)) { throw }
    }

    if (!$Object) {
        try {
            $Deleted = Invoke-MtGraphRequest -ApiVersion 'beta' `
                -RelativeUri "directory/deletedItems/$Id" `
                -Select @('id', 'displayName') -ErrorAction Stop
            $DeletedType = [string]$Deleted.'@odata.type'
            if ($DeletedType -in $AcceptedTypes) {
                $Object = $Deleted
                $Status = 'Soft deleted'
            }
        } catch {
            if (!(Test-MtGraphNotFoundError -ErrorRecord $_)) { throw }
        }
    }

    [pscustomobject]@{
        Type        = $Endpoint.Name
        Id          = $Id
        DisplayName = if ($Object) { [string]$Object.displayName } else { '' }
        Status      = $Status
    }
}
