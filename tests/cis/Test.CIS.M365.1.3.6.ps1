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

    Write-Verbose 'Requesting organization configuration to get the customer lockbox setting'
    $customerLockbox = @(Get-MtExo -Request OrganizationConfig | Select-Object CustomerLockBoxEnabled)

    if ($customerLockbox.Count -eq 0) {
        Add-MtTestResultDetail -SkippedBecause NotAuthorized
        return $null
    }

    Write-Verbose 'Checking if the customer lockbox feature is enabled'
    $result = $customerLockbox | Where-Object { $_.CustomerLockBoxEnabled -ne 'True' }

    $testResult = ($result | Measure-Object).Count -eq 0
    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant has the customer lockbox enabled:`n`n%TestResult%"
    }
    else {
        $testResultMarkdown = "Your tenant does not have the customer lockbox enabled:`n`n%TestResult%"
    }

    $resultMd = "| Customer Lockbox |`n"
    $resultMd += "| --- |`n"
    foreach ($item in $customerLockbox) {
        $itemResult = "❌ Fail"
        if ($item.CustomerLockBoxEnabled -eq 'True') {
            $itemResult = "✅ Pass"
        }
        $resultMd += "| $($itemResult) |`n"
    }

    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $resultMd

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
