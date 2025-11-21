<#
.SYNOPSIS
    Gets the global settings from the Maester config.
.DESCRIPTION
    This function retrieves the value of the specified global setting from the Maester config.
    It returns the value of the specified global setting, which may be of any type depending on the configuration.
.EXAMPLE
    $globalSettings = Get-MtMaesterConfigGlobalSetting -SettingName 'EmergencyAccessAccounts'
    # This will return the global settings for the setting with name 'EmergencyAccessAccounts'.
#>

function Get-MtMaesterConfigGlobalSetting {
    [CmdletBinding()]
    [OutputType([object])]
    param(
        # The setting name of the configuration for which to retrieve the settings.
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$SettingName
    )

    # Check if the Maester config is loaded
    if (-not ($__MtSession -and $__MtSession.MaesterConfig -and $__MtSession.MaesterConfig.GlobalSettings )) {
        Write-Verbose "Maester global config not loaded. Please run Get-MtMaesterConfig first to load the config."
        return $null
    } else {
        Write-Verbose "Maester global config loaded"
        Write-Verbose "Maester global config `"$SettingName`": $($__MtSession.MaesterConfig.GlobalSettings.$SettingName | ConvertTo-Json -Depth 5 -Compress)"
    }

    # Retrieve the test settings from the Maester config
    return $__MtSession.MaesterConfig.GlobalSettings.$SettingName
}