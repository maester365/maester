function Test-MtAdDaclUnresolvedSidCount {
    <#
    .SYNOPSIS
    Counts unresolved SID references in Active Directory DACL entries.

    .DESCRIPTION
    This test reviews DACL entries from Get-MtADDomainState and identifies ACEs whose
    IdentityReference still appears as a raw domain SID. These orphaned SID references
    can indicate deleted accounts, stale delegations, or incomplete cleanup after
    migrations and privilege changes.

    .EXAMPLE
    Test-MtAdDaclUnresolvedSidCount

    Returns $true if DACL data is accessible.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdDaclUnresolvedSidCount
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
    $unresolvedEntries = @(
        $daclEntries | Where-Object {
            [string]$_.IdentityReference -like 'S-1-5-21-*'
        }
    )

    $distinctUnresolvedSidCount = @(
        $unresolvedEntries |
            Group-Object -Property IdentityReference
    ).Count

    $testResult = $true

    $result = '| Metric | Value |`n'
    $result += '| --- | --- |`n'
    $result += "| Total DACL Entries | $($daclEntries.Count) |`n"
    $result += "| ACEs with Unresolved SID IdentityReference | $($unresolvedEntries.Count) |`n"
    $result += "| Distinct Unresolved SIDs | $distinctUnresolvedSidCount |`n"

    $testResultMarkdown = "Active Directory DACL identities were analyzed. $distinctUnresolvedSidCount unresolved SID reference(s) were found across $($unresolvedEntries.Count) ACE(s).`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $result

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
