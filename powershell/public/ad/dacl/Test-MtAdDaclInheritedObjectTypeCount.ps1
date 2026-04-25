function Test-MtAdDaclInheritedObjectTypeCount {
    <#
    .SYNOPSIS
    Counts inherited object types referenced by Active Directory DACL entries.

    .DESCRIPTION
    This test analyzes DACL entries from Get-MtADDomainState and counts distinct
    inherited object type GUIDs that are explicitly targeted by ACE inheritance.
    Reviewing inherited object type scope helps identify how broadly delegated access
    applies to descendant object classes.

    .EXAMPLE
    Test-MtAdDaclInheritedObjectTypeCount

    Returns $true if DACL data is accessible.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdDaclInheritedObjectTypeCount
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $adState = Get-MtADDomainState
    if ($null -eq $adState) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory
        return $null
    }

    if (-not ($adState.PSObject.Properties.Name -contains 'DaclEntries')) {
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

    $distinctInheritedObjectTypeCount = @(
        $filteredEntries |
            Group-Object -Property InheritedObjectType
    ).Count

    $testResult = $true

    $result = '| Metric | Value |`n'
    $result += '| --- | --- |`n'
    $result += "| Total DACL Entries | $($daclEntries.Count) |`n"
    $result += "| ACEs with Specific InheritedObjectType | $($filteredEntries.Count) |`n"
    $result += "| Distinct InheritedObjectType GUIDs | $distinctInheritedObjectTypeCount |`n"

    $testResultMarkdown = "Active Directory DACL inheritance targets were analyzed. $distinctInheritedObjectTypeCount distinct inherited object type GUID(s) were referenced across $($filteredEntries.Count) ACE(s).`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $result

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
