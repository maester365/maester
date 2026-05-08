function Test-MtCisCommunicateInitiateExternalTeamsUsers {
    <#
    .SYNOPSIS
    Ensure external Teams users cannot initiate conversations

    .DESCRIPTION
    External Teams users cannot initiate conversations
    CIS Microsoft 365 Foundations Benchmark v6.0.1

    .EXAMPLE
    Test-MtCisCommunicateInitiateExternalTeamsUsers

    Returns true if external Teams users cannot initiate conversations

    .LINK
    https://maester.dev/docs/commands/Test-MtCisCommunicateInitiateExternalTeamsUsers
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'This test checks multiple users.')]
    param()

    if (-not (Test-MtConnection Teams)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedTeams
        return $null
    }

    Write-Verbose 'Test-MtCisCommunicateInitiateExternalTeamsUsers: Checking if external unmanaged Teams users cannot initiate conversations'

    try {
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
    catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
