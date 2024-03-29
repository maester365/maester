<#
.SYNOPSIS
    Add detailed information about a test so that it can be displayed in the test results report.

.DESCRIPTION
    This function is used to add detailed information about a test so that it can be displayed in the test results report.

    All parameters support Markdown format.
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