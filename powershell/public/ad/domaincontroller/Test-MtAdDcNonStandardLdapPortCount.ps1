function Test-MtAdDcNonStandardLdapPortCount {
    <#
    .SYNOPSIS
    Counts domain controllers using non-standard LDAP ports.

    .DESCRIPTION
    This test identifies domain controllers that are not using the standard LDAP port (389).
    Non-standard LDAP ports may indicate custom configurations that could affect compatibility
    with standard LDAP clients and tools, or could be used to bypass security monitoring.

    .EXAMPLE
    Test-MtAdDcNonStandardLdapPortCount

    Returns $true if DC data is accessible.
    The test result includes the count of DCs using non-standard LDAP ports.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdDcNonStandardLdapPortCount
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

    $domainControllers = $adState.DomainControllers
    $dcCount = ($domainControllers | Measure-Object).Count

    # Count DCs with non-standard LDAP port (standard is 389)
    $standardLdapPort = 389
    $nonStandardLdapDCs = $domainControllers | Where-Object { $_.LdapPort -ne $standardLdapPort }
    $nonStandardCount = ($nonStandardLdapDCs | Measure-Object).Count
    $standardCount = $dcCount - $nonStandardCount

    # Test passes if we successfully retrieved DC data
    $testResult = $dcCount -gt 0

    # Generate markdown results
    $result = "| Metric | Value |`n"
    $result += "| --- | --- |`n"
    $result += "| Total Domain Controllers | $dcCount |`n"
    $result += "| DCs Using Standard LDAP Port (389) | $standardCount |`n"
    $result += "| DCs Using Non-Standard LDAP Port | $nonStandardCount |`n"

    if ($nonStandardCount -gt 0) {
        $result += "| Non-Standard Port DCs | $($nonStandardLdapDCs.Name -join ', ') |`n"
        $result += "| Non-Standard Ports | $($nonStandardLdapDCs.LdapPort -join ', ') |`n"
        $testResultMarkdown = "⚠️ **Configuration Notice**: $nonStandardCount domain controller(s) are using non-standard LDAP ports. While this may be intentional for specific scenarios, it can affect compatibility with standard LDAP clients.`n`n%TestResult%"
    } else {
        $testResultMarkdown = "✅ **Standard Configuration**: All $dcCount domain controller(s) are using the standard LDAP port (389).`n`n%TestResult%"
    }

    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}



