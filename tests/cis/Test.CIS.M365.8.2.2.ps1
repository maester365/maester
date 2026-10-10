function Test-MtCisCommunicateWithUnmanagedTeamsUsers {
    <#
    .SYNOPSIS
    Ensure communication with unmanaged Teams users is disabled

    .DESCRIPTION
    Communication with unmanaged Teams users is disabled
    CIS Microsoft 365 Foundations Benchmark v7.0.0 (8.2.2, L1)

    .EXAMPLE
    Test-MtCisCommunicateWithUnmanagedTeamsUsers

    Returns true if communication with unmanaged Teams users is disabled

    .LINK
    https://maester.dev/docs/commands/Test-MtCisCommunicateWithUnmanagedTeamsUsers
    #>
    [MaesterTest(
        Id = 'CIS.M365.8.2.2',
        Title = 'Ensure communication with unmanaged Teams users is disabled',
        Severity = 'Medium',
        Category = 'CIS',
        Product = 'Teams',
        Tag = ('CIS E3 Level 1', 'CIS M365 v7.0.0'),
        Service = 'Teams',
        Author = 'HenrikPiecha',
        Contributor = ('merill', 'Mynster9361')
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'This test checks multiple users.')]
    param()

    Write-Verbose 'Test-MtCisCommunicateWithUnmanagedTeamsUsers: Checking if communication with unmanaged Teams users is disabled'

    $AllowTeamsConsumer = Get-CsTenantFederationConfiguration | Select-Object -ExpandProperty AllowTeamsConsumer
    if ($AllowTeamsConsumer -eq $false) {
        Add-MtTestResultDetail -Result 'Well done. Communication with unmanaged Teams users is disabled.'
        return $true
    } else {
        $ExternalAccessPolicy = Get-CsExternalAccessPolicy -Identity Global
        if ($ExternalAccessPolicy.EnableTeamsConsumerAccess -eq $false) {
            Add-MtTestResultDetail -Result 'Well done. Communication with unmanaged Teams users is disabled.'
            return $true
        } else {
            Add-MtTestResultDetail -Result 'Communication with unmanaged Teams users is enabled.'
            return $false
        }
    }
}
