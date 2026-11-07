function Test-MtCisCustomerLockBox {
    <#
    .SYNOPSIS
    Checks if the customer lockbox feature is enabled

    .DESCRIPTION
    The customer lockbox feature should be enabled
    CIS Microsoft 365 Foundations Benchmark v7.0.0 (1.3.6)

    .EXAMPLE
    Test-MtCisCustomerLockBox

    Returns true if the customer lockbox feature is enabled

    .LINK
    https://maester.dev/docs/commands/Test-MtCisCustomerLockBox
    #>
    [MaesterTest(
        Id = 'CIS.M365.1.3.6',
        Title = 'Ensure the customer lockbox feature is enabled',
        Product = 'microsoft-365',
        RelatedProduct = 'purview',
        Feature = 'organization-settings',
        Area = 'access-control',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = 'T1199',
        Control = 'cis-m365:1.3.6',
        Service = 'ExchangeOnline',
        License = 'LOCKBOX_ENTERPRISE',
        Author = 'NZLostboy',
        Contributor = ('SamErde', 'Mynster9361')
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Requesting secure scores to get the customer lockbox setting'
    $customerLockbox = Get-MtExo -Request OrganizationConfig | Select-Object CustomerLockBoxEnabled

    $usableConfig = @($customerLockbox | Where-Object { $null -ne $_ -and $null -ne $_.CustomerLockBoxEnabled })
    if ($usableConfig.Count -eq 0) {
        # An empty collection filters to nothing, so the count below is zero and that is the pass.
        # Without this guard the check reports the customer lockbox as enabled for a tenant whose
        # organization configuration was never read.
        Add-MtTestResultDetail -SkippedBecause NotAuthorized
        return $null
    }

    Write-Verbose 'Checking if the customer lockbox feature is enabled'
    $result = $usableConfig | Where-Object { $_.CustomerLockBoxEnabled -ne 'True' }

    # Set the result to true and pass if no tenants are found with the customer lockbox feature disabled.
    $testResult = ($result | Measure-Object).Count -eq 0
    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant has the customer lockbox enabled:`n`n%TestResult%"
    } else {
        $testResultMarkdown = "Your tenant does not have the customer lockbox enabled:`n`n%TestResult%"
    }

    # The table is built for both outcomes. It used to be built only on failure while the
    # -replace below consumed it either way, so a passing tenant rendered an empty table and the
    # expression would throw under Set-StrictMode.
    $resultMd = "| Customer Lockbox |`n"
    $resultMd += "| --- |`n"
    foreach ($item in $usableConfig) {
        # The projection above keeps only CustomerLockBoxEnabled, so there is no id to compare
        # against. Reading the value directly is also what the single-column table means: an
        # identity comparison here left both sides $null, and $null -notin $null is False, so
        # every row rendered as a failure, including under the "Well done" heading.
        $itemResult = if ($item.CustomerLockBoxEnabled -eq 'True') { "✅ Pass" } else { "❌ Fail" }
        $resultMd += "| $($itemResult) |`n"
    }

    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $resultMd

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
