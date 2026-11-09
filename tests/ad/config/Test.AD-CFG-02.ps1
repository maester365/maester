function Test-MtAdDsHeuristicsCount {
    <#
    .SYNOPSIS
    Reports Active Directory dSHeuristics for review.

    .DESCRIPTION
    Phase 14 (AD Configuration tests) - AD-CFG-02.
    Reports the configured dSHeuristics string for human review. Its positions
    have independent meanings; the string length is not a count of settings.

    .EXAMPLE
    Test-MtAdDsHeuristicsCount

    Returns $true if configuration data is accessible.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdDsHeuristicsCount
    #>
    [MaesterTest(
        Id = 'AD-CFG-02',
        Title = 'dSHeuristics value should be investigated',
        Product = 'ad',
        Feature = 'directory-configuration',
        Area = 'infrastructure',
        ResourceType = 'Tenant',
        Severity = 'Info',
        Mitre = 'None',
        Service = 'ActiveDirectory',
        Permission = ('ActiveDirectory:Ldap:Configuration/*:ReadProperty'),
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Starting Test-MtAdDsHeuristicsCount"

    $adState = Get-MtADDomainState -Categories @('Configuration')

    if ($null -eq $adState -or $null -eq $adState.Configuration) {
        throw 'Directory Service configuration could not be retrieved.'
    }

    $config = $adState.Configuration
    if ($config.PSObject.Properties.Name -contains 'DirectoryServiceRetrieved' -and $config.DirectoryServiceRetrieved -ne $true) {
        throw 'Directory Service object could not be retrieved; dSHeuristics is unknown.'
    }
    $dsHeuristics = $config.DsHeuristics

    $value = if ([string]::IsNullOrEmpty([string]$dsHeuristics)) { '(not set)' } else { [string]$dsHeuristics }
    Add-MtTestResultDetail -Result "Review the position-specific dSHeuristics value against your directory baseline: $value" -Investigate
    return $true
}
