function Test-MtAdKdsRootKeysCount {
    <#
    .SYNOPSIS
    Verifies that an acceptable number of KDS root keys exists in Active Directory.

    .DESCRIPTION
    KDS root keys are required for Group Managed Service Accounts (gMSA). This test
    checks the number of KDS root keys configured in the domain.

    - Zero keys indicates gMSAs are not in use, so the test is skipped.
    - Exactly one key is the recommended configuration; the test passes.
    - Exactly two keys can cause gMSA authentication failures in some scenarios;
      the test returns Investigate per Microsoft guidance.
    - Three or more keys is also acceptable (Microsoft's recommended workaround
      for the two-key sorting issue is to create a third key); the test passes.

    .EXAMPLE
    Test-MtAdKdsRootKeysCount

    Returns $true when the KDS root key count is acceptable (1 or 3+).

    .LINK
    https://maester.dev/docs/commands/Test-MtAdKdsRootKeysCount
    #>
    [MaesterTest(
        Id = 'AD-CFG-22',
        Title = 'KDS root key count should be acceptable',
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

    Write-Verbose "Starting Test-MtAdKdsRootKeysCount"

    # Get AD domain state data (uses cached data if available)
    $adState = Get-MtADDomainState -Categories @('Configuration')

    # If unable to retrieve AD data, skip the test
    if ($null -eq $adState) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory
        return $null
    }

    $config = $adState.Configuration

    # If the KDS query failed or the entire Configuration category is unavailable, skip
    if ($null -eq $config) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Unable to retrieve Active Directory configuration. The query may have failed or returned no data.'
        return $null
    }
    if ($null -eq $config.KdsRootKeys) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Unable to retrieve KDS root key information. Ensure you have appropriate permissions.'
        return $null
    }

    # Count valid KDS root keys (those with a creation timestamp)
    $kdsRootKeys = @($config.KdsRootKeys | Where-Object { $null -ne $_.'msKds-CreateTime' })
    $kdsRootKeysCount = ($kdsRootKeys | Measure-Object).Count

    # Build the metric table once so both result paths can include it
    $result = "| Metric | Value |" + "`n"
    $result += "| --- | --- |" + "`n"
    $result += "| KDS Root Keys (gMSA) | $kdsRootKeysCount |" + "`n"
    $result += "| Recommended Count | 1 |" + "`n"

    # Zero keys means gMSAs are not deployed; skip the test
    if ($kdsRootKeysCount -eq 0) {
        Add-MtTestResultDetail -SkippedBecause 'Custom' -SkippedCustomReason 'No KDS root keys found. Group Managed Service Accounts (gMSA) are not in use in this environment.'
        return $null
    }

    # Exactly one key is the desired state; three or more is also acceptable per Microsoft guidance
    # (the workaround for the sorting issue is to create a third key)
    # Two keys triggers an Investigate result per the Microsoft article
    if ($kdsRootKeysCount -eq 2) {
        $testResultMarkdown = "⚠️ Exactly two KDS root keys exist. In some scenarios this can cause gMSA authentication failures. Microsoft's recommended workaround is to create a third KDS root key. Do not remove existing keys. See [Microsoft documentation](https://learn.microsoft.com/troubleshoot/windows-server/active-directory/gmsa-auth-failures-multiple-keys) for details.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
        Add-MtTestResultDetail -Result $testResultMarkdown -Investigate
        return $null
    }

    $testResult = ($kdsRootKeysCount -eq 1) -or ($kdsRootKeysCount -ge 3)

    if ($testResult) {
        $testResultMarkdown = "✅ KDS root key count is acceptable. This is the recommended configuration for gMSA operations.`n`n%TestResult%"
    }

    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
