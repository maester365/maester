function Get-MtMdeConfig {
    <#
    .SYNOPSIS
        Gets MDE configuration settings from the Maester global settings

    .DESCRIPTION
        Reads MDE-specific settings (ComplianceLogic, PolicyFiltering) from
        GlobalSettings.MdeConfig in maester-config.json. Falls back to sensible
        code-based defaults if the settings are not present.

        Users can customize these settings by adding an MdeConfig object under
        GlobalSettings in their ./Custom/maester-config.json file.

    .EXAMPLE
        $config = Get-MtMdeConfig

        Returns a hashtable with ComplianceLogic and PolicyFiltering settings.

    .LINK
        https://maester.dev/docs/commands/Get-MtMdeConfig
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    $defaults = @{
        ComplianceLogic = "AllPolicies"
        PolicyFiltering = "OnlyAssigned"
    }

    $mdeConfig = Get-MtMaesterConfigGlobalSetting -SettingName 'MdeConfig'

    if ($mdeConfig) {
        return @{
            ComplianceLogic = if ($mdeConfig.ComplianceLogic) { $mdeConfig.ComplianceLogic } else { $defaults.ComplianceLogic }
            PolicyFiltering = if ($mdeConfig.PolicyFiltering) { $mdeConfig.PolicyFiltering } else { $defaults.PolicyFiltering }
        }
    }

    Write-Verbose "MdeConfig not found in GlobalSettings. Using defaults: ComplianceLogic=$($defaults.ComplianceLogic), PolicyFiltering=$($defaults.PolicyFiltering)"
    return $defaults
}
