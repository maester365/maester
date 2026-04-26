function Test-MtAdComputerOperatingSystemCount {
    <#
    .SYNOPSIS
    Counts the number of distinct operating systems in use by domain computers.

    .DESCRIPTION
    This test identifies the diversity of operating systems in the Active Directory
    environment. High OS diversity may indicate inconsistent patching, legacy systems,
    or unsupported operating systems that require attention.

    Security Value:
    - Identifies legacy or unsupported operating systems
    - Helps prioritize upgrade paths
    - Reveals potential security gaps from outdated systems
    - Supports compliance reporting on system standardization

    .EXAMPLE
    Test-MtAdComputerOperatingSystemCount

    Returns $true if computer data is accessible.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdComputerOperatingSystemCount
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Starting Test-MtAdComputerOperatingSystemCount"
    $adState = Get-MtADDomainState
    Write-Verbose "Retrieved AD state"

    if ($null -eq $adState) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory
        return $null
    }
    Write-Verbose "Filtering/counting computer operating system count"

    $computers = $adState.Computers

    # Group by operating system
    $osGroups = $computers | Where-Object { $_.operatingSystem } | Group-Object -Property operatingSystem
    $osCount = ($osGroups | Measure-Object).Count
    $totalComputers = ($computers | Measure-Object).Count
    $computersWithOs = ($computers | Where-Object { $_.operatingSystem } | Measure-Object).Count
    $computersWithoutOs = $totalComputers - $computersWithOs

    $testResult = $true

    $result = "| Metric | Value |`n"
    $result += "| --- | --- |`n"
    $result += "| Total Computers | $totalComputers |`n"
    $result += "| Distinct Operating Systems | $osCount |`n"
    $result += "| Computers with OS Data | $computersWithOs |`n"
    $result += "| Computers without OS Data | $computersWithoutOs |`n"

    if ($osCount -gt 0) {
        $result += "`n**Operating Systems in Use:**`n`n"
        $result += "| Operating System | Count | Percentage |`n"
        $result += "| --- | --- | --- |`n"

        $sortedGroups = $osGroups | Sort-Object -Property Count -Descending
        foreach ($group in $sortedGroups) {
            $percentage = if ($computersWithOs -gt 0) { [Math]::Round(($group.Count / $computersWithOs) * 100, 2) } else { 0 }
            $result += "| $($group.Name) | $($group.Count) | $percentage% |`n"
        }
    }
    Write-Verbose "Counts computed"

    $testResultMarkdown = "Domain computer operating system diversity has been analyzed.`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown
    Write-Verbose "Completed Test-MtAdComputerOperatingSystemCount"

    return $testResult
}


