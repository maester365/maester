function Test-MtAdDcNonStandardLdapsPortCount {
    <#
    .SYNOPSIS
    Counts domain controllers using non-standard LDAPS ports.

    .DESCRIPTION
    This test identifies domain controllers that are not using the standard LDAPS port (636).
    Non-standard LDAPS ports may indicate custom configurations that could affect compatibility
    with secure LDAP clients and tools, or could be used to bypass security monitoring.

    .EXAMPLE
    Test-MtAdDcNonStandardLdapsPortCount

    Returns $true if DC data is accessible.
    The test result includes the count of DCs using non-standard LDAPS ports.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdDcNonStandardLdapsPortCount
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

    # Count DCs with non-standard LDAPS port (standard is 636)
    $standardLdapsPort = 636
    $nonStandardLdapsDCs = $domainControllers | Where-Object { $_.SslPort -ne $standardLdapsPort }
    $nonStandardCount = ($nonStandardLdapsDCs | Measure-Object).Count
    $standardCount = $dcCount - $nonStandardCount

    # Test passes if we successfully retrieved DC data
    $testResult = $dcCount -gt 0

    # Generate markdown results
    $result = "| Metric | Value |`n"
    $result += "| --- | --- |`n"
    $result += "| Total Domain Controllers | $dcCount |`n"
    $result += "| DCs Using Standard LDAPS Port (636) | $standardCount |`n"
    $result += "| DCs Using Non-Standard LDAPS Port | $nonStandardCount |`n"

    if ($nonStandardCount -gt 0) {
        $result += "| Non-Standard Port DCs | $($nonStandardLdapsDCs.Name -join ', ') |`n"
        $result += "| Non-Standard Ports | $($nonStandardLdapsDCs.SslPort -join ', ') |`n"
        $testResultMarkdown = "⚠️ **Configuration Notice**: $nonStandardCount domain controller(s) are using non-standard LDAPS ports. While this may be intentional for specific scenarios, it can affect compatibility with secure LDAP clients.`n`n%TestResult%"
    } else {
        $testResultMarkdown = "✅ **Standard Configuration**: All $dcCount domain controller(s) are using the standard LDAPS port (636).`n`n%TestResult%"
    }

    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
