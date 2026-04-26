function Test-MtAdComputerOperatingSystemDetails {
    <#
    .SYNOPSIS
    Provides detailed breakdown of computers by operating system and service pack.

    .DESCRIPTION
    This test provides a comprehensive view of the operating system landscape in the
    domain, including OS versions and service pack levels. This helps identify
    outdated systems, unsupported versions, and systems requiring security updates.

    Security Value:
    - Identifies end-of-life operating systems
    - Reveals systems missing critical service packs
    - Supports vulnerability management programs
    - Helps plan OS upgrade and standardization efforts

    .EXAMPLE
    Test-MtAdComputerOperatingSystemDetails

    Returns $true if computer data is accessible.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdComputerOperatingSystemDetails
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Clarity in using plural')]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $adState = Get-MtADDomainState

    if ($null -eq $adState) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory
        return $null
    }

    $computers = $adState.Computers

    # Create detailed OS breakdown including service pack
    $osDetails = $computers | Where-Object { $_.operatingSystem } | ForEach-Object {
        $osName = $_.operatingSystem
        $osServicePack = if ($_.operatingSystemServicePack) { $_.operatingSystemServicePack } else { "No Service Pack" }
        "$osName $osServicePack"
    } | Group-Object

    $totalComputers = ($computers | Measure-Object).Count
    $computersWithOs = ($computers | Where-Object { $_.operatingSystem } | Measure-Object).Count

    $testResult = $true

    $result = "| Metric | Value |`n"
    $result += "| --- | --- |`n"
    $result += "| Total Computers | $totalComputers |`n"
    $result += "| Computers with OS Data | $computersWithOs |`n"
    $result += "| Distinct OS/Service Pack Combinations | $(($osDetails | Measure-Object).Count) |`n"

    if ($osDetails.Count -gt 0) {
        $result += "`n**Operating System Details (Top 15):**`n`n"
        $result += "| Operating System | Count | Percentage |`n"
        $result += "| --- | --- | --- |`n"

        $sortedDetails = $osDetails | Sort-Object -Property Count -Descending | Select-Object -First 15
        foreach ($detail in $sortedDetails) {
            $percentage = if ($computersWithOs -gt 0) { [Math]::Round(($detail.Count / $computersWithOs) * 100, 2) } else { 0 }
            $result += "| $($detail.Name) | $($detail.Count) | $percentage% |`n"
        }

        if ($osDetails.Count -gt 15) {
            $result += "| ... and $($osDetails.Count - 15) more combinations | | |`n"
        }
    }

    $testResultMarkdown = "Detailed operating system distribution has been analyzed. Review for unsupported or end-of-life systems.`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}


