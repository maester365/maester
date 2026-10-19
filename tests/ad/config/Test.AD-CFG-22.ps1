function Test-MtAdKdsRootKeysCount {
    <#
    .SYNOPSIS
    Verifies that the KDS root key configuration in Active Directory follows
    Microsoft guidance.

    .DESCRIPTION
    KDS root keys are required for Group Managed Service Accounts (gMSA). This test
    checks the number of KDS root keys configured in the domain.

    - Zero keys indicates gMSAs are not in use, so the test is skipped.
    - Exactly one key is the recommended configuration; the test passes.
    - Exactly two keys can cause gMSA authentication failures in specific sorting
      scenarios and should be investigated.
    - Three or more keys is the documented Microsoft workaround; the test passes.

    .EXAMPLE
    Test-MtAdKdsRootKeysCount

    Returns $true if the KDS root key count follows Microsoft guidance.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdKdsRootKeysCount
    #>
    [MaesterTest(
        Id = 'AD-CFG-22',
        Title = 'KDS root key count should follow Microsoft guidance',
        Product = 'ad',
        Feature = 'directory-configuration',
        Area = 'infrastructure',
        ResourceType = 'Tenant',
        Severity = 'Info',
        Mitre = 'None',
        Service = 'ActiveDirectory',
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

    # If the KDS query failed, we cannot determine the count
    if ($null -eq $config -or $null -eq $config.KdsRootKeys) {
        Add-MtTestResultDetail -Result "Unable to retrieve KDS root key information. Ensure you have appropriate permissions and the Active Directory module is installed."
        return $false
    }

    # Count valid KDS root keys (those with a creation timestamp)
    $kdsRootKeys = @($config.KdsRootKeys | Where-Object { $null -ne $_.'msKds-CreateTime' })
    $kdsRootKeysCount = ($kdsRootKeys | Measure-Object).Count

    # Zero keys means gMSAs are not deployed; skip the test
    if ($kdsRootKeysCount -eq 0) {
        Add-MtTestResultDetail -SkippedBecause 'Custom' -SkippedCustomReason 'No KDS root keys found. Group Managed Service Accounts (gMSA) are not in use in this environment.'
        return $null
    }

    # Evaluate against Microsoft guidance:
    # - 1 key: recommended (pass)
    # - 2 keys: can cause gMSA failures in specific sorting cases (investigate)
    # - 3+ keys: documented workaround (pass)
    $testResult = ($kdsRootKeysCount -eq 1) -or ($kdsRootKeysCount -ge 3)
    $needsInvestigate = $kdsRootKeysCount -eq 2

    # Generate markdown results
    $result = "| Metric | Value |" + "`n"
    $result += "| --- | --- |" + "`n"
    $result += "| KDS Root Keys (gMSA) | $kdsRootKeysCount |" + "`n"
    $result += "| Recommended Count | 1 |" + "`n"

    if ($testResult) {
        $testResultMarkdown = "✅ $kdsRootKeysCount KDS root key(s) exist. This follows Microsoft guidance for gMSA operations.`n`n%TestResult%"
    } elseif ($needsInvestigate) {
        $testResultMarkdown = "⚠️ Exactly 2 KDS root keys exist. In specific sorting scenarios this can cause gMSA authentication failures. Microsoft recommends creating a third key as a workaround rather than removing existing keys. See [Microsoft documentation](https://learn.microsoft.com/troubleshoot/windows-server/active-directory/gmsa-auth-failures-multiple-keys) for details.`n`n%TestResult%"
    } else {
        $testResultMarkdown = "⚠️ $kdsRootKeysCount KDS root keys exist. Review the key configuration against Microsoft guidance. See [Microsoft documentation](https://learn.microsoft.com/troubleshoot/windows-server/active-directory/gmsa-auth-failures-multiple-keys) for details.`n`n%TestResult%"
    }

    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    if ($needsInvestigate) {
        Add-MtTestResultDetail -Result $testResultMarkdown -Investigate
        return $null
    } else {
        Add-MtTestResultDetail -Result $testResultMarkdown
        return $testResult
    }
}
