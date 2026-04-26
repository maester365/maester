function Test-MtAdDaclInheritedObjectTypeDetails {
    <#
    .SYNOPSIS
    Returns inherited object type breakdown from Active Directory DACL entries.

    .DESCRIPTION
    This test analyzes DACL entries from Get-MtADDomainState and groups ACEs by the
    specific inherited object type GUID they target. This helps reviewers understand
    which descendant object classes are in scope for inherited delegations.

    .EXAMPLE
    Test-MtAdDaclInheritedObjectTypeDetails

    Returns $true if DACL data is accessible.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdDaclInheritedObjectTypeDetails
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $adState = Get-MtADDomainState
    if ($null -eq $adState) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory
        return $null
    }

    if (-not ($adState.ContainsKey('DaclEntries'))) {
        Add-MtTestResultDetail -Result 'Unable to retrieve Active Directory DACL entries from Get-MtADDomainState.'
        return $false
    }

    $daclEntries = @($adState.DaclEntries | Where-Object { $null -ne $_ })
    $filteredEntries = @(
        $daclEntries | Where-Object {
            $inheritedObjectType = [string]$_.InheritedObjectType
            -not [string]::IsNullOrWhiteSpace($inheritedObjectType) -and
            $inheritedObjectType -ne '00000000-0000-0000-0000-000000000000'
        }
    )

    $groups = @(
        $filteredEntries |
            Group-Object -Property InheritedObjectType |
            Sort-Object @{ Expression = 'Count'; Descending = $true }, @{ Expression = 'Name'; Descending = $false }
    )

    $result = '| InheritedObjectType | ACE Count | Distinct ObjectDN Count |`n'
    $result += '| --- | --- | --- |`n'

    foreach ($group in $groups) {
        $inheritedObjectType = [string]$group.Name
        $inheritedObjectType = $inheritedObjectType -replace '\|', '\\&#124;'

        $distinctObjectCount = @(
            $group.Group |
                Group-Object -Property ObjectDN
        ).Count

        $result += "| $inheritedObjectType | $($group.Count) | $distinctObjectCount |`n"
    }

    $testResult = $true
    $testResultMarkdown = "Active Directory DACL inheritance targets were grouped by inherited object type. $($groups.Count) inherited object type GUID group(s) were identified.`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $result

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
