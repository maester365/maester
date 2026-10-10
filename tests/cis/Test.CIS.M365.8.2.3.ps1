function Test-MtCisCommunicateInitiateExternalTeamsUsers {
    <#
    .SYNOPSIS
    Ensure external Teams users cannot initiate conversations

    .DESCRIPTION
    External Teams users cannot initiate conversations
    CIS Microsoft 365 Foundations Benchmark v7.0.0 (8.2.3)

    .EXAMPLE
    Test-MtCisCommunicateInitiateExternalTeamsUsers

    Returns true if external Teams users cannot initiate conversations

    .LINK
    https://maester.dev/docs/commands/Test-MtCisCommunicateInitiateExternalTeamsUsers
    #>
    [MaesterTest(
        Id = 'CIS.M365.8.2.3',
        Title = 'Ensure external Teams users cannot initiate conversations',
        Severity = 'Medium',
        Category = 'CIS',
        Product = 'Teams',
        Tag = ('CIS E3 Level 1', 'CIS M365 v7.0.0'),
        Service = 'Teams',
        Author = 'Mynster9361',
        Contributor = 'merill'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'This test checks multiple users.')]
    param()

    Write-Verbose 'Test-MtCisCommunicateInitiateExternalTeamsUsers: Checking if external unmanaged Teams users cannot initiate conversations'

    $AllowTeamsConsumerInbound = Get-CsTenantFederationConfiguration | Select-Object -ExpandProperty AllowTeamsConsumerInbound
    if ($AllowTeamsConsumerInbound -eq $false) {
        Add-MtTestResultDetail -Result 'Well done. External unmanaged Teams users cannot initiate conversations.'
        return $true
    }
    else {
        $ExternalAccessPolicy = Get-CsExternalAccessPolicy -Identity Global
        if ($ExternalAccessPolicy.EnableTeamsConsumerInbound -eq $false) {
            Add-MtTestResultDetail -Result 'Well done. External unmanaged Teams users cannot initiate conversations.'
            return $true
        }
        else {
            Add-MtTestResultDetail -Result 'External unmanaged Teams users can initiate conversations.'
            return $false
        }
    }
}
