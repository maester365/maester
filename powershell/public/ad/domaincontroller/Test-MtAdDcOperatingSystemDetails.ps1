function Test-MtAdDcOperatingSystemDetails {
    <#
    .SYNOPSIS
    Provides detailed breakdown of operating systems on domain controllers.

    .DESCRIPTION
    This test provides a detailed breakdown showing how many domain controllers
    are running each operating system version. This helps identify DCs that may
    need to be upgraded or migrated to newer OS versions.

    .EXAMPLE
    Test-MtAdDcOperatingSystemDetails

    Returns $true if DC operating system data is accessible.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdDcOperatingSystemDetails
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

    # Group DCs by operating system
    $osGroups = $domainControllers | Where-Object { $_.OperatingSystem } | Group-Object -Property OperatingSystem

    # Test passes if we successfully retrieved DC data
    $testResult = $dcCount -gt 0

    # Generate markdown results
    $result = "| Metric | Value |`n"
    $result += "| --- | --- |`n"
    $result += "| Total Domain Controllers | $dcCount |`n"
    $result += "| Distinct Operating Systems | $($osGroups.Count) |`n`n"

    $result += "| Operating System | DC Count | Percentage | Domain Controllers |`n"
    $result += "| --- | --- | --- | --- |`n"

    foreach ($osGroup in ($osGroups | Sort-Object -Property Count -Descending)) {
        $osName = $osGroup.Name
        $count = $osGroup.Count
        $percentage = [Math]::Round(($count / $dcCount) * 100, 2)
        $dcNames = ($osGroup.Group | Select-Object -ExpandProperty Name | Sort-Object) -join ', '
        $result += "| $osName | $count | $percentage% | $dcNames |`n"
    }

    # Add DCs with unknown/missing OS info
    $unknownOS = $domainControllers | Where-Object { -not $_.OperatingSystem }
    $unknownCount = ($unknownOS | Measure-Object).Count
    if ($unknownCount -gt 0) {
        $unknownNames = ($unknownOS | Select-Object -ExpandProperty Name | Sort-Object) -join ', '
        $result += "| Unknown/Missing | $unknownCount | - | $unknownNames |`n"
    }

    $testResultMarkdown = "Domain controller operating system distribution has been analyzed across $dcCount DC(s).`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}



