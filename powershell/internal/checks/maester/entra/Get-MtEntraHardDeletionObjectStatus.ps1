function Get-MtEntraHardDeletionObjectStatus {
    <#
    .SYNOPSIS
    Returns the Hard Deletion Protection status of one object listed in the Maester config.

    .DESCRIPTION
    Reads the object from Microsoft Graph beta. Status is 'Protected', 'Not protected', 'Soft deleted' or
    'Not found'. An object that cannot be read as an active object is 'Soft deleted' when it appears in the
    supplied protected objects as soft deleted, and 'Not found' otherwise. Any Graph error other than
    HTTP 404 is thrown.

    .PARAMETER Configured
    A HardDeletionProtectedObjects entry with Type and Id.

    .PARAMETER ProtectedObject
    The output of Get-MtEntraHardDeletionProtectedObject.

    .EXAMPLE
    Get-MtEntraHardDeletionObjectStatus -Configured $Entry -ProtectedObject $Protected
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [object] $Configured,

        [Parameter()]
        [AllowEmptyCollection()]
        [object[]] $ProtectedObject = @()
    )

    $EndpointByType = @{
        user             = 'users'
        group            = 'groups'
        application      = 'applications'
        serviceprincipal = 'servicePrincipals'
    }
    $TypeNames = @{
        user             = 'User'
        group            = 'Group'
        application      = 'Application'
        serviceprincipal = 'ServicePrincipal'
    }

    $Type = ([string]$Configured.Type).ToLowerInvariant()
    if (!$EndpointByType.ContainsKey($Type) -or [string]::IsNullOrWhiteSpace($Configured.Id)) {
        throw (
            "Invalid HardDeletionProtectedObjects entry (Type '$($Configured.Type)', Id '$($Configured.Id)'). " +
            'Type must be User, Group, Application or ServicePrincipal and Id must be an object ID.'
        )
    }

    $Object = $null
    try {
        $Object = Invoke-MtGraphRequest -ApiVersion 'beta' `
            -RelativeUri "$($EndpointByType[$Type])/$($Configured.Id)" `
            -Select @('id', 'displayName', 'isHardDeleteProtectionEnabled') -ErrorAction Stop
    } catch {
        if ($_.Exception.Response.StatusCode -ne [System.Net.HttpStatusCode]::NotFound) { throw }
    }

    $DisplayName = ''
    $Status = 'Not found'
    if ($Object) {
        $DisplayName = [string]$Object.displayName
        $Status = if ($Object.isHardDeleteProtectionEnabled -eq $true) { 'Protected' } else { 'Not protected' }
    } else {
        $Deleted = @($ProtectedObject | Where-Object { $_.Id -eq [string]$Configured.Id -and $_.State -eq 'Soft deleted' })
        if ($Deleted.Count -gt 0) {
            $DisplayName = $Deleted[0].DisplayName
            $Status = 'Soft deleted'
        }
    }

    [pscustomobject]@{
        Type        = $TypeNames[$Type]
        Id          = [string]$Configured.Id
        DisplayName = $DisplayName
        Status      = $Status
    }
}
