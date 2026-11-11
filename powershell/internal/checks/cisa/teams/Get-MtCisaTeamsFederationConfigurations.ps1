function Get-MtCisaTeamsFederationConfigurations {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Teams can return multiple federation configurations.')]
    [OutputType([object[]])]
    param()

    if (-not $__MtSession.TeamsCache.ContainsKey('FederationConfigurations')) {
        $__MtSession.TeamsCache['FederationConfigurations'] = @(Get-CsTenantFederationConfiguration -ErrorAction Stop)
    }

    $configurations = @($__MtSession.TeamsCache['FederationConfigurations'])
    if ($configurations.Count -eq 0) {
        throw 'Teams returned no tenant federation configurations.'
    }
    return $configurations
}
