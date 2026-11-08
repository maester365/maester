function Test-MtAdKdsRootKeysCount {
    <#
    .SYNOPSIS
    Verifies that an acceptable number of KDS root keys exists in Active Directory.

    .DESCRIPTION
    KDS root keys are required for Group Managed Service Accounts (gMSA). This test
    checks the number of KDS root keys configured in the domain.

    - Zero keys means gMSA provisioning cannot work; the test fails.
    - One key supports gMSA operations; the test passes.
    - Exactly two keys can cause gMSA authentication failures in some scenarios;
      the test returns Investigate per Microsoft guidance.
    - Three or more keys is also acceptable (Microsoft's recommended workaround
      for the two-key sorting issue is to create a third key); the test passes.

    .EXAMPLE
    Test-MtAdKdsRootKeysCount

    Returns $true when at least one KDS root key exists and the two-key issue does not apply.

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
        Severity = 'Low',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
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

    if ($null -eq $adState) {
        throw 'Unable to retrieve the AD configuration needed to count KDS root keys.'
    }

    $config = $adState.Configuration

    # A missing category is not evidence that there are zero keys.
    if ($null -eq $config) {
        throw 'Unable to retrieve Active Directory configuration; KDS root key inventory is unknown.'
    }
    if ($null -eq $config.KdsRootKeys) {
        throw 'Unable to retrieve KDS root key information; check directory access.'
    }

    # Do not silently drop keys whose metadata was not returned.
    $kdsRootKeys = @($config.KdsRootKeys | Where-Object { $null -ne $_ })
    if (@($kdsRootKeys | Where-Object { $null -eq $_.'msKds-CreateTime' }).Count -gt 0) {
        throw 'KDS root key creation metadata was not returned; the key inventory is incomplete.'
    }
    $kdsRootKeysCount = ($kdsRootKeys | Measure-Object).Count

    # Build the metric table once so both result paths can include it
    $result = "| Metric | Value |" + "`n"
    $result += "| --- | --- |" + "`n"
    $result += "| KDS Root Keys (gMSA) | $kdsRootKeysCount |" + "`n"
    # No keys means gMSA provisioning is unavailable; this does not prove gMSAs are unused.
    if ($kdsRootKeysCount -eq 0) {
        Add-MtTestResultDetail -Result "No KDS root keys were found. gMSA provisioning requires a KDS root key; review whether gMSAs are planned or already in use.`n`n$result"
        return $false
    }

    # A nonzero count establishes presence, not a universal recommended key count.
    # Two keys triggers an Investigate result per the Microsoft article
    if ($kdsRootKeysCount -eq 2) {
        $testResultMarkdown = "⚠️ Exactly two KDS root keys exist. In some scenarios this can cause gMSA authentication failures. Microsoft's recommended workaround is to create a third KDS root key. Do not remove existing keys. See [Microsoft documentation](https://learn.microsoft.com/troubleshoot/windows-server/active-directory/gmsa-auth-failures-multiple-keys) for details.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
        Add-MtTestResultDetail -Result $testResultMarkdown -Investigate
        return $true
    }

    $testResult = ($kdsRootKeysCount -eq 1) -or ($kdsRootKeysCount -ge 3)

    if ($testResult) {
        $testResultMarkdown = "Well done. KDS root keys are present for gMSA operations.`n`n%TestResult%"
    }

    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
