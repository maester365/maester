<#
.SYNOPSIS
    Add detailed information about a test so that it can be displayed in the test results report.

.DESCRIPTION
    This function is used to add detailed information about a test so that it can be displayed in the test results report.

    All parameters support Markdown format.

.EXAMPLE
    Add-MtTestResultDetail -Description 'Test description' -Result 'Test result'

    This example adds detailed information about a test with a brief description and the result of the test.

    ```powershell
            # Markdown should start from the beginning of the line with no leading spaces
            $testDescription = "
It is recommended to have at least one emergency/break glass account or account group excluded from all conditional access policies.
This allows for emergency access to the tenant in case of a misconfiguration or other issues.

See [Manage emergency access accounts in Microsoft Entra ID - Microsoft Learn](https://learn.microsoft.com/entra/identity/role-based-access-control/security-emergency-access)"
        $testResult = "These conditional access policies don't have the emergency access account or group excluded:`n`n"
        # Check if the emergency access account or group is excluded from all policies and write verbose output
        $policies | Where-Object { $CheckId -notin $_.conditions.users.excludeUsers -and $CheckId -notin $_.conditions.users.excludeGroups } | Select-Object -ExpandProperty displayName | Sort-Object | ForEach-Object {
            $testResult += "  - [$_](https://entra.microsoft.com/#view/Microsoft_AAD_ConditionalAccess/PolicyBlade/policyId/$($_.id)?%23view/Microsoft_AAD_ConditionalAccess/ConditionalAccessBlade/~/Policies?=)`n"
            Write-Verbose "Conditional Access policy $_ does not exclude emergency access account or group"
        }
        Add-MtTestResultDetail -Description $testDescription -Result $testResult
    ```
#>

Function Add-MtTestResultDetail {
    [CmdletBinding()]
    param(
        # Brief description of what this test is checking.
        [Parameter(Mandatory = $true)]
        [string] $Description,

        # Detailed information of the test result to provide additional context to the user.
        # This can be a summary of the items that caused the test to fail (e.g. list of user names, conditional access policies, etc.).
        [Parameter(Mandatory = $true)]
        [string] $Result
    )

    $testName = $____Pester.CurrentTest.Name # Get the test name from the Pester context.

    $testInfo = @{
        TestDescription = $Description
        TestResult      = $Result
    }
    $MtTestResultDetail[$testName] = $testInfo
}