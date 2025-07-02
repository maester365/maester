<#
.SYNOPSIS
    Checks if the customer lockbox feature is enabled

.DESCRIPTION
    The customer lockbox feature should be enabled
    CIS Microsoft 365 Foundations Benchmark v5.0.0

.EXAMPLE
    Test-MtCisCustomerLockBox

    Returns true if the customer lockbox feature is enabled

.LINK
    https://maester.dev/docs/commands/Test-MtCisCustomerLockBox
#>
function Test-MtCisCustomerLockBox {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (!(Test-MtConnection ExchangeOnline)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedExchange
        return $null
    }

    try {
        Write-Verbose 'Requesting secure scores to get the customer lockbox setting'
        $customerLockbox = Get-MtExo -Request OrganizationConfig | Select-Object CustomerLockBoxEnabled

        Write-Verbose 'Checking if the customer lockbox feature is enabled'
        $result = $customerLockbox | Where-Object { $_.CustomerLockBoxEnabled -ne 'True' }

        # Set the result to true and pass if no tenants are found with the customer lockbox feature disabled.
        $testResult = ($result | Measure-Object).Count -eq 0
        if ($testResult) {
            $testResultMarkdown = "Well done. Your tenant has the customer lockbox enabled:`n`n%TestResult%"
        } else {
            $testResultMarkdown = "Your tenant does not have the customer lockbox enabled:`n`n%TestResult%"
        }

        # Prepare the markdown result table if the test fails (testResult is false).
        if ($testResult -eq $false) {
            $resultMd = "| Customer Lockbox |`n"
            $resultMd += "| --- |`n"
            foreach ($item in $customerLockbox) {
                $itemResult = "❌ Fail"
                if ($item.id -notin $result.id) {
                    $itemResult = "✅ Pass"
                }
                $resultMd += "| $($itemResult) |`n"
            }
        }

        $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $resultMd

        Add-MtTestResultDetail -Result $testResultMarkdown
        return $testResult
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
