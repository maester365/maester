function Test-MtAdDcOperatingSystemCount {
    <#
    .SYNOPSIS
    Counts the distinct operating systems running on domain controllers.

    .DESCRIPTION
    This test identifies the number of unique operating system versions running
    on domain controllers in the domain. Having multiple OS versions can indicate
    a need for standardization or an ongoing migration project.

    .EXAMPLE
    Test-MtAdDcOperatingSystemCount

    Returns $true if DC operating system data is accessible.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdDcOperatingSystemCount
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

    $domainControllers = $adState.DomainControllers
    $dcCount = ($domainControllers | Measure-Object).Count

    # Get unique operating systems
    $uniqueOS = $domainControllers | Select-Object -ExpandProperty OperatingSystem -Unique | Where-Object { $_ }
    $uniqueOSCount = ($uniqueOS | Measure-Object).Count

    # Test passes if we successfully retrieved DC data
    $testResult = $dcCount -gt 0

    # Generate markdown results
    $result = "| Metric | Value |`n"
    $result += "| --- | --- |`n"
    $result += "| Total Domain Controllers | $dcCount |`n"
    $result += "| Distinct Operating Systems | $uniqueOSCount |`n"

    if ($uniqueOSCount -gt 0) {
        $result += "| Operating Systems | $($uniqueOS -join ', ') |`n"
    }

    $testResultMarkdown = "Domain controller operating systems have been analyzed. There are $uniqueOSCount distinct OS version(s) across $dcCount domain controller(s).`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
