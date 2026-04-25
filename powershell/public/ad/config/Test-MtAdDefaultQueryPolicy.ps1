function Test-MtAdDefaultQueryPolicy {
    <#
    .SYNOPSIS
    Returns default LDAP query policy limits from Active Directory.

    .DESCRIPTION
    This test retrieves the LDAP query policy named "Default-Query-Policy" and reports the configured
    LDAPAdminLimits when available.

    .EXAMPLE
    Test-MtAdDefaultQueryPolicy

    Returns $true if LDAP query policy data is accessible.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdDefaultQueryPolicy
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    # Get AD domain state data (uses cached data if available)
    $adState = Get-MtADDomainState

    # If unable to retrieve AD data, skip the test
    if ($null -eq $adState) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory
        return $null
    }

    $config = $adState.Configuration
    $ldapQueryPolicies = if ($null -ne $config -and $null -ne $config.LdapQueryPolicies) { @($config.LdapQueryPolicies) } else { @() }

    $defaultQueryPolicies = $ldapQueryPolicies | Where-Object { $_.Name -eq "Default-Query-Policy" }
    $defaultQueryPolicyCount = ($defaultQueryPolicies | Measure-Object).Count

    $defaultPolicy = $defaultQueryPolicies | Select-Object -First 1
    $ldapAdminLimits = if ($null -ne $defaultPolicy -and $defaultPolicy.PSObject.Properties.Name -contains 'LDAPAdminLimits') { $defaultPolicy.LDAPAdminLimits } else { $null }

    $ldapAdminLimitsText = if ($null -ne $ldapAdminLimits) {
        try {
            ($ldapAdminLimits | ConvertTo-Json -Depth 10 -Compress)
        } catch {
            $ldapAdminLimits.ToString()
        }
    } else {
        'Not available'
    }

    # Test passes if we successfully retrieved query policy data
    $testResult = $null -ne $config -and $null -ne $config.LdapQueryPolicies

    # Generate markdown results
    if ($testResult) {
        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Default-Query-Policy Count | $defaultQueryPolicyCount |`n"
        $result += "| LDAPAdminLimits | $ldapAdminLimitsText |`n"

        $testResultMarkdown = "Active Directory default query policy limits have been analyzed. Default-Query-Policy found: $defaultQueryPolicyCount.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve LDAP query policy information. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
