function Get-MtSetting {
    <#
    .SYNOPSIS
    Returns a setting from GlobalSettings in the Maester config.

    .DESCRIPTION
    Tests read their tenant-wide settings (for example EmergencyAccessAccounts) through this command.
    The value comes from GlobalSettings in the run config; when the config does not set it, the default
    from the settings registry is returned, else the -Default value.

    .PARAMETER Name
    The name of the setting, for example EmergencyAccessAccounts. Test packs can use Namespace.Key names.

    .PARAMETER Default
    The value to return when neither the config nor the settings registry has one.

    .EXAMPLE
    Get-MtSetting -Name EmergencyAccessAccounts

    Returns the emergency access accounts configured for the run.

    .LINK
    https://maester.dev/docs/commands/Get-MtSetting
    #>
    [Alias('Get-MtMaesterConfigGlobalSetting')]
    [CmdletBinding()]
    [OutputType([object], [object[]])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [Alias('SettingName')]
        [string] $Name,

        [Parameter()]
        [AllowNull()]
        [object] $Default
    )

    $globalSettings = if ($__MtSession -and $__MtSession.MaesterConfig -and $__MtSession.MaesterConfig.PSObject.Properties['GlobalSettings']) { $__MtSession.MaesterConfig.GlobalSettings } else { $null }
    if ($globalSettings -and $globalSettings.PSObject.Properties[$Name]) {
        $value = $globalSettings.$Name
        Write-Verbose "Maester setting `"$Name`": $($value | ConvertTo-Json -Depth 5 -Compress)"
        return $value
    }
    if (-not $script:__MtSettingsRegistry) {
        $script:__MtSettingsRegistry = Import-PowerShellDataFile -Path (Join-Path $ExecutionContext.SessionState.Module.ModuleBase 'assets/MaesterSettings.psd1')
    }
    foreach ($key in $script:__MtSettingsRegistry.Settings.Keys) {
        if ($key -eq $Name) {
            # Arrays are returned with the comma operator so an empty default stays an empty array.
            return , $script:__MtSettingsRegistry.Settings[$key].Default
        }
    }
    $Default
}
