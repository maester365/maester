function Test-MtCisFabricTenantSetting {
    <#
    .SYNOPSIS
    Preserves the CIS entry point for the shared Fabric tenant-setting evaluator.

    .DESCRIPTION
    Delegates to the service-neutral evaluator without changing existing CIS audit rules or results.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $SettingName,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $SettingTitle,

        [Parameter(Mandatory)]
        [ValidateSet('DisabledOrGroups', 'PublishToWeb', 'Disabled', 'Enabled')]
        [string] $Rule
    )

    return Test-MtFabricTenantSetting -SettingName $SettingName -SettingTitle $SettingTitle -Rule $Rule
}
