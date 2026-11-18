function Get-MtEntraHardDeletionObjectStatus {
    <#
    .SYNOPSIS
    Returns the Hard Deletion Protection status of one object listed in the Maester config.

    .DESCRIPTION
    Reads the object from Microsoft Graph beta. Status is 'Protected', 'Not protected', 'Soft deleted' or
    'Not found'. When the active lookup returns HTTP 404, the function looks for the object among the deleted
    items of the same type. It reports 'Soft deleted' when it finds the object there, whether or not the object
    has protection, and 'Not found' when neither lookup finds it. Any Graph error other than a 404 is thrown.

    The Id must be the object ID, a GUID. The function uses its canonical lower-case form in both requests and
    in the result, so the result matches the objects that Get-MtEntraHardDeletionProtectedObject returns.

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

    $EndpointByType = @{
        user             = @{ Name = 'User'; Path = 'users'; GraphType = 'user' }
        group            = @{ Name = 'Group'; Path = 'groups'; GraphType = 'group' }
        application      = @{ Name = 'Application'; Path = 'applications'; GraphType = 'application' }
        serviceprincipal = @{ Name = 'ServicePrincipal'; Path = 'servicePrincipals'; GraphType = 'servicePrincipal' }
    }

    $Type = ([string]$Configured.Type).ToLowerInvariant()
    $ParsedId = [guid]::Empty
    if (!$EndpointByType.ContainsKey($Type) -or ![guid]::TryParse([string]$Configured.Id, [ref]$ParsedId)) {
        throw (
            "Invalid HardDeletionProtectedObjects entry (Type '$($Configured.Type)', Id '$($Configured.Id)'). " +
            'Type must be User, Group, Application or ServicePrincipal and Id must be the object ID (a GUID).'
        )
    }
    $Endpoint = $EndpointByType[$Type]
    $Id = $ParsedId.ToString()

    $Object = $null
    $Status = 'Not found'
    try {
        $Object = Invoke-MtGraphRequest -ApiVersion 'beta' -RelativeUri "$($Endpoint.Path)/$Id" `
            -Select @('id', 'displayName', 'isHardDeleteProtectionEnabled') -ErrorAction Stop
        $Status = if ($Object.isHardDeleteProtectionEnabled -eq $true) { 'Protected' } else { 'Not protected' }
    } catch {
        if (!(Test-MtGraphNotFoundError -ErrorRecord $_)) { throw }
    }

    if (!$Object) {
        try {
            $Object = Invoke-MtGraphRequest -ApiVersion 'beta' `
                -RelativeUri "directory/deletedItems/microsoft.graph.$($Endpoint.GraphType)/$Id" `
                -Select @('id', 'displayName') -ErrorAction Stop
            $Status = 'Soft deleted'
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
