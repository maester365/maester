function Test-MtAdDaclNonInheritedAceCount {
    <#
    .SYNOPSIS
    Counts non-inherited ACEs in Active Directory DACLs.

    .DESCRIPTION
    This test analyzes DACL entries from Get-MtADDomainState and counts ACEs that are
    explicitly assigned rather than inherited. Non-inherited ACEs are often where
    custom delegations, exceptions, and potentially risky access grants are introduced.

    .EXAMPLE
    Test-MtAdDaclNonInheritedAceCount

    Returns $true if DACL data is accessible.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdDaclNonInheritedAceCount
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
    $nonInheritedEntries = @(
        $daclEntries | Where-Object {
            $_.IsInherited -eq $false -or [string]$_.IsInherited -eq 'False'
        }
    )

    $testResult = $true

    $result = '| Metric | Value |`n'
    $result += '| --- | --- |`n'
    $result += "| Total DACL Entries | $($daclEntries.Count) |`n"
    $result += "| Non-Inherited ACEs | $($nonInheritedEntries.Count) |`n"

    $testResultMarkdown = "Active Directory DACL inheritance was analyzed. $($nonInheritedEntries.Count) ACE(s) are explicitly assigned and not inherited.`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $result

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
