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
    [MaesterTest(
        Id = 'AD-DCOMP-04',
        Title = 'Computer operating system count should be investigated',
        Product = 'ad',
        Feature = 'computers',
        Area = 'devices',
        ResourceType = 'Computer',
        Severity = 'Info',
        Mitre = 'None',
        Control = 'nist-800-53-r5:CM-8',
        Service = 'ActiveDirectory',
        Permission = ('ActiveDirectory:Ldap:computer:ReadProperty'),
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Starting Test-MtAdComputerOperatingSystemCount"
    $adState = Get-MtADDomainState -Categories @('Computers')
    Write-Verbose "Retrieved AD state"

    if ($null -eq $adState -or $null -eq $adState.Computers) {
        throw 'Computer inventory is required to review operating systems.'
    }
    Write-Verbose "Filtering/counting computer operating system count"

    $computers = $adState.Computers

    # Blank and whitespace-only values are undefined, not distinct operating systems.
    $osGroups = $computers | Where-Object { -not [string]::IsNullOrWhiteSpace($_.operatingSystem) } | Group-Object -Property operatingSystem
    $osCount = ($osGroups | Measure-Object).Count
    $totalComputers = ($computers | Measure-Object).Count
    $computersWithOs = ($computers | Where-Object { -not [string]::IsNullOrWhiteSpace($_.operatingSystem) } | Measure-Object).Count
    $computersWithoutOs = $totalComputers - $computersWithOs

    $testResult = $true

    $result = "| Metric | Value |" + "`n"
    $result += "| --- | --- |" + "`n"
    $result += "| Total Computers | $totalComputers |" + "`n"
    $result += "| Distinct Operating Systems | $osCount |" + "`n"
    $result += "| Computers with OS Data | $computersWithOs |" + "`n"
    $result += "| Computers with Unknown OS | $computersWithoutOs |" + "`n"

    if ($totalComputers -gt 0) {
        $result += "`n**Operating Systems in Use:**" + "`n" + "`n"
        $result += "| Operating System | Count | Percentage of All Computers |" + "`n"
        $result += "| --- | --- | --- |" + "`n"

        $sortedGroups = $osGroups | Sort-Object -Property Count -Descending
        foreach ($group in $sortedGroups) {
            $percentage = [Math]::Round(($group.Count / $totalComputers) * 100, 2)
            $osName = [string]$group.Name -replace '\|', '\|' -replace '[\r\n]', ' '
            $result += "| $osName | $($group.Count) | $percentage% |" + "`n"
        }
        if ($computersWithoutOs -gt 0) {
            $unknownPercentage = [Math]::Round(($computersWithoutOs / $totalComputers) * 100, 2)
            $result += "| Unknown OS | $computersWithoutOs | $unknownPercentage% |`n"
        }
    }
    Write-Verbose "Counts computed"

    $testResultMarkdown = "Review the operating system inventory, including computers with unknown OS. OS service pack is not collected; this inventory cannot determine patch or support status.`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown -Investigate
    Write-Verbose "Completed Test-MtAdComputerOperatingSystemCount"

    return $testResult
}
