function Test-MtAdEnrollmentTemplatesCount {
    <#
    .SYNOPSIS
    Counts the number of certificate templates available for enrollment.

    .DESCRIPTION
    This test retrieves the Active Directory configuration data for enrollment templates
    and reports how many templates are available for enrollment.

    .EXAMPLE
    Test-MtAdEnrollmentTemplatesCount

    .LINK
    https://maester.dev/docs/commands/Test-MtAdEnrollmentTemplatesCount
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    # Get AD domain state data (uses cached data if available)
    $adState = Get-MtADDomainState

    # If unable to retrieve AD data, skip the test
    if ($null -eq $adState) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory
        return $null
    }

    $config = $adState.Configuration
    $enrollmentTemplates = $config.EnrollmentTemplates
    $enrollmentTemplatesCount = @($enrollmentTemplates).Count
    $hasData = $null -ne $config.EnrollmentTemplates

    # Test passes when configuration data is available
    $testResult = $hasData -and ($enrollmentTemplatesCount -ge 0)

    # Generate markdown results
    if ($hasData) {
        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Enrollment Templates Count | $enrollmentTemplatesCount |`n"
        $testResultMarkdown = "Active Directory enrollment templates have been counted. $enrollmentTemplatesCount enrollment template(s) were found.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory configuration data for EnrollmentTemplates. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}


