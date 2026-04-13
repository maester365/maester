<#
.SYNOPSIS
    Gets MDE configuration settings from the Maester config

.DESCRIPTION
    Reads MDE-specific settings (ComplianceLogic, PolicyFiltering) from the
    MdeConfig section of maester-config.json. Falls back to sensible defaults
    if the config is not loaded or the MdeConfig section is not present.

    Users can customize these settings by adding an MdeConfig section to their
    ./Custom/maester-config.json file.

.EXAMPLE
    $config = Get-MtMdeConfig

    Returns a hashtable with ComplianceLogic and PolicyFiltering settings.

.LINK
    https://maester.dev/docs/tests/mde
#>

function Get-MtMdeConfig {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    $defaults = @{
        ComplianceLogic = "AllPolicies"
        PolicyFiltering = "OnlyAssigned"
    }

    if ($__MtSession -and $__MtSession.MaesterConfig -and $__MtSession.MaesterConfig.MdeConfig) {
        $mdeConfig = $__MtSession.MaesterConfig.MdeConfig
        return @{
            ComplianceLogic = if ($mdeConfig.ComplianceLogic) { $mdeConfig.ComplianceLogic } else { $defaults.ComplianceLogic }
            PolicyFiltering = if ($mdeConfig.PolicyFiltering) { $mdeConfig.PolicyFiltering } else { $defaults.PolicyFiltering }
        }
    }

    Write-Verbose "MdeConfig not found in Maester config. Using defaults: ComplianceLogic=$($defaults.ComplianceLogic), PolicyFiltering=$($defaults.PolicyFiltering)"
    return $defaults
}
