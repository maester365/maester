function Test-MtAdLdapQueryPolicyCount {
    <#
    .SYNOPSIS
    Counts Active Directory LDAP query policies.

    .DESCRIPTION
    Phase 14 (AD Configuration tests) - AD-CFG-06.
    This test retrieves $config.LdapQueryPolicies and returns the count of configured LDAP query policies.

    .EXAMPLE
    Test-MtAdLdapQueryPolicyCount

    Returns $true if configuration data is accessible.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdLdapQueryPolicyCount
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $adState = Get-MtADDomainState

    if ($null -eq $adState) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory
        return $null
    }

    $config = $adState.Configuration
    $ldapQueryPolicies = if ($null -ne $config) { $config.LdapQueryPolicies } else { $null }
    $ldapQueryPoliciesSafe = if ($null -ne $ldapQueryPolicies) { @($ldapQueryPolicies) } else { @() }

    $ldapQueryPolicyCount = ($ldapQueryPoliciesSafe | Measure-Object).Count
    $testResult = $null -ne $config

    if ($testResult) {
        $result = "| Property | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| LDAP Query Policies Count | $ldapQueryPolicyCount |`n`n"

        $testResultMarkdown = "Active Directory LDAP query policies have been counted.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    }
    else {
        $testResultMarkdown = "Unable to retrieve Active Directory configuration. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}


