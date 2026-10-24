function Test-MtAdKdsRootKeysCount {
    <#
    .SYNOPSIS
    Verifies that exactly one KDS root key exists in Active Directory.

    .DESCRIPTION
    KDS root keys are required for Group Managed Service Accounts (gMSA). This test
    checks the number of KDS root keys configured in the domain.

    - Zero keys indicates gMSAs are not in use, so the test is skipped.
    - Exactly one key is the recommended configuration; the test passes.
    - More than one key can cause gMSA authentication failures and the test fails.

    .EXAMPLE
    Test-MtAdKdsRootKeysCount

    Returns $true if exactly one KDS root key exists.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdKdsRootKeysCount
    #>
    [MaesterTest(
        Id = 'AD-CFG-22',
        Title = 'Exactly one KDS root key should exist',
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

    # Exactly one key is the desired state
    $testResult = $kdsRootKeysCount -eq 1

    # Generate markdown results
    $result = "| Metric | Value |" + "`n"
    $result += "| --- | --- |" + "`n"
    $result += "| KDS Root Keys (gMSA) | $kdsRootKeysCount |" + "`n"
    $result += "| Recommended Count | 1 |" + "`n"

    if ($testResult) {
        $testResultMarkdown = "✅ Exactly one KDS root key exists. This is the recommended configuration for gMSA operations.`n`n%TestResult%"
    } else {
        $testResultMarkdown = "⚠️ $kdsRootKeysCount KDS root keys exist. Having multiple KDS root keys can cause gMSA authentication failures. Consider reviewing the key creation process and removing unnecessary keys. See [Microsoft documentation](https://learn.microsoft.com/troubleshoot/windows-server/active-directory/gmsa-auth-failures-multiple-keys) for details.`n`n%TestResult%"
    }

    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
