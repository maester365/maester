function Get-MtAdConfigurationInventory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $State,
        [Parameter(Mandatory)] [string[]] $Required
    )

    if ($null -eq $State -or $null -eq $State.Configuration) {
        throw 'Active Directory configuration data is unavailable.'
    }
    foreach ($name in $Required) {
        if ($null -eq $State.Configuration.PSObject.Properties[$name] -or $null -eq $State.Configuration.$name) {
            throw "Active Directory configuration $name data is unavailable."
        }
    }
    return $State.Configuration
}
