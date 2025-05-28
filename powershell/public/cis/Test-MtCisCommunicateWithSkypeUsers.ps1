<#
.SYNOPSIS
    Ensure communication with Skype users is disabled

.DESCRIPTION
    Communication with Skype users is disabled
    CIS Microsoft 365 Foundations Benchmark v5.0.0

.EXAMPLE
    Test-MtCisCommunicateWithSkypeUsers

    Returns true if communication with Skype users is disabled

.LINK
    https://maester.dev/docs/commands/Test-MtCisCommunicateWithSkypeUsers
#>
function Test-MtCisCommunicateWithSkypeUsers {
    [CmdletBinding()]
    [OutputType([bool])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'This test checks multiple users.')]
    param()

    if (-not (Test-MtConnection Teams)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedTeams
        return $null
    }
    Write-Verbose "Test-MtCisCommunicateWithSkypeUsers: Checking if communication with Skype users is disabled"
    $return = $true
    try {
        $CsTenantFederationConfiguration = Get-CsTenantFederationConfiguration
        if ($CsTenantFederationConfiguration.AllowPublicUsers -ne $true) {
            Add-MtTestResultDetail -Result "Well done. Communication with Skype users is disabled."
        } else {
            Add-MtTestResultDetail -Result "Communication with Skype users is enabled."
            $return = $false
        }
    } catch {
        $return = $false
        Write-Error $_.Exception.Message
    }
    return $return
}
