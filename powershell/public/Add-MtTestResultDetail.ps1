<#
.SYNOPSIS
    Add detailed information about a test so that it can be displayed in the test results report.

.DESCRIPTION
    This function is used to add detailed information about a test so that it can be displayed in the test results report.

    The description and result support markdown format.

    If the calling script/cmdlet has a markdown file with the same name as the script/cmdlet,
    it will be used to populate the description and result fields.

    A good example is the markdown for the Test-MtCaEmergencyAccessExists cmdlet:
        - https://github.com/maester365/maester/blob/main/powershell/public/Test-MtCaEmergencyAccessExists.md
        - https://github.com/maester365/maester/blob/main/powershell/public/Test-MtCaEmergencyAccessExists.ps1

    The markdown file can include a seperator `<!--- Results --->` to split the description and result sections.
    This allows for the overview and detailed information to be displayes separately in the Test results.

.EXAMPLE
    Add-MtTestResultDetail -Description 'Test description' -Result 'Test result'

    This example adds detailed information about a test with a brief description and the result of the test.

    ```powershell
        $policiesWithoutEmergency = $policies | Where-Object { $CheckId -notin $_.conditions.users.excludeUsers -and $CheckId -notin $_.conditions.users.excludeGroups }

        Add-MtTestResultDetail -GraphObjects $policiesWithoutEmergency -GraphObjectType ConditionalAccess
    ```

    This example shows how to use the Add-MtTestResultDetail function to add rich markdown content to the test results with deep links to the admin portal.

.LINK
    https://maester.dev/docs/commands/Add-MtTestResultDetail
#>
function Add-MtTestResultDetail {
    [CmdletBinding()]
    param(
        # Brief description of what this test is checking.
        # Markdown is supported.
        [Parameter(Mandatory = $false)]
        [string] $Description,

        # Detailed information of the test result to provide additional context to the user.
        # This can be a summary of the items that caused the test to fail (e.g. list of user names, conditional access policies, etc.).
        # Markdown is supported.
        # If the test result contains a placeholder %TestResult%, it will be replaced with the values from the $GraphResult
        [Parameter(Mandatory = $false)]
        [string] $Result,

        # Collection of Graph objects to display in the test results report.
        # This will be inserted into the contents of Result parameter if the result contains a placeholder %TestResult%.
        [Object[]] $GraphObjects,

        # The type of graph object, this will be used to show the right deeplink to the test results report.
        [ValidateSet('AuthenticationMethod', 'AuthorizationPolicy', 'ConditionalAccess', 'ConsentPolicy',
            'Devices', 'Domains', 'Groups', 'IdentityProtection', 'Users', 'UserRole'
        )]
        [string] $GraphObjectType,

        # Pester test name
        # Use the test name from the Pester context by default
        [Parameter(Mandatory = $false)]
        [string] $TestName = $____Pester.CurrentTest.ExpandedName,

        # A custom title for the test in the format of "MT.XXXX: <TestName>. Used in data driven tests like Entra recommendations 1024"
        [Parameter(Mandatory = $false)]
        [string] $TestTitle,

        [Parameter(Mandatory = $false)]
        [ValidateSet('NotConnectedAzure', 'NotConnectedExchange', 'NotConnectedGraph', 'NotDotGovDomain', 'NotLicensedEntraIDP1', 'NotConnectedSecurityCompliance', 'NotConnectedTeams',
            'NotLicensedEntraIDP2', 'NotLicensedEntraIDGovernance', 'NotLicensedEntraWorkloadID', 'NotLicensedExoDlp', "LicensedEntraIDPremium", 'NotSupported', 'Custom',
            'NotLicensedMdo', 'NotLicensedMdoP2', 'NotLicensedMdoP1', 'NotLicensedAdvAudit', 'NotLicensedEop', 'Error'
        )]
        # Common reasons for why the test was skipped.
        [string] $SkippedBecause,

        [Parameter(Mandatory = $false)]
        # A custom reason for why the test was skipped. Requires `-SkippedBecause Custom`.
        [string] $SkippedCustomReason,

        [Parameter(Mandatory = $false)]
        # The error object that caused the test to be skipped.
        $SkippedError,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Critical', 'High', 'Medium', 'Low', 'Info', '')]
        # Severity level of the test result. Leave empty if no Severity is defined yet.
        [string] $Severity
    )

    $hasGraphResults = $GraphObjects -and $GraphObjectType

    if ($SkippedBecause) {
        if ($SkippedBecause -eq 'Custom') {
            if ([string]::IsNullOrEmpty($SkippedCustomReason)) {
                throw "SkippedBecause is set to 'Custom' but no SkippedCustomReason was provided."
            }
            $SkippedReason = $SkippedCustomReason
        } elseif ($SkippedBecause -eq 'Error') {

            $SkippedReason = "An error occurred while running the test. ⚠️"
            if ($SkippedError) {
                $SkippedReason += "`n`n" + '```' + "`n`n" + ($SkippedError | Out-String) + "`n`n" + '```' + "`n`n"
            }
        } else {
            $SkippedReason = Get-MtSkippedReason $SkippedBecause
        }
    }

    if ([string]::IsNullOrEmpty($Result)) {
        $Result = "Skipped. $SkippedReason"
    }

    if ([string]::IsNullOrEmpty($Description)) {
        # Check if a markdown file exists for the cmdlet and parse the content
        $cmdletPath = $MyInvocation.PSCommandPath
        $markdownPath = $cmdletPath -replace '.ps1', '.md'
        if (Test-Path $markdownPath) {
            # Read the content and split it into description and result with "<!--- Results --->" as the separator
            $content = Get-Content $markdownPath -Raw
            $splitContent = $content -split "<!--- Results --->"
            $mdDescription = $splitContent[0]
            $mdResult = $splitContent[1]

            if (![string]::IsNullOrEmpty($Result)) {
                # If a result was provided in the parameter insert it into the markdown content
                if ($mdResult -match "%TestResult%") {
                    $mdResult = $mdResult -replace "%TestResult%", $Result
                } else {
                    $mdResult = $Result
                }
            }

            $Description = $mdDescription
            $Result = $mdResult
        }
    }

    if ($hasGraphResults) {
        $graphResultMarkdown = Get-GraphObjectMarkdown -GraphObjects $GraphObjects -GraphObjectType $GraphObjectType
        $Result = $Result -replace "%TestResult%", $graphResultMarkdown
    }

    if ([string]::IsNullOrEmpty($TestTitle)) {
        # If no test title is provided, use the test name
        $TestTitle = $____Pester.CurrentTest.ExpandedName
    }

    if ([string]::IsNullOrEmpty($Severity)) {
        # Check if the test has a severity tag using the internal helper function
        $Severity = Get-MtPesterTagValue -TagName 'Severity'
    }

    $Service = Get-MtPesterTagValue -TagName 'Service'

    $testInfo = @{
        TestTitle       = $TestTitle
        TestDescription = $Description
        TestResult      = $Result
        TestSkipped     = $SkippedBecause
        SkippedReason   = $SkippedReason
        Severity        = $Severity
        Service         = $Service
    }

    Write-MtProgress -Activity "Running tests" -Status $testName
    Write-Verbose "Adding test result detail for $testName"
    # Write-Verbose "Description: $Description" # Makes it VERY verbose
    Write-Verbose "Result: $Result"

    if ($__MtSession -and $__MtSession.TestResultDetail) {
        if (![string]::IsNullOrEmpty($testName)) {
            # Only set if we are running in the context of Maester

            # Check if the test name is already in the session and display a warning
            $__MtSession.TestResultDetail[$testName] = $testInfo
        }
    }

    if ($SkippedBecause) {
        #This needs to be set at the end.
        Set-ItResult -Skipped -Because $SkippedReason
    }
}
