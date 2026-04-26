function Test-MtAdDaclOuObjectCount {
    <#
    .SYNOPSIS
    Counts DACL entries on Organizational Unit objects.

    .DESCRIPTION
    This informational test filters collected DACL data to Organizational Unit objects and counts
    the number of ACEs present on those OU objects. OU permissions are security-relevant because OUs
    are common delegation boundaries for administration, policy application, and object management in
    Active Directory.

    .EXAMPLE
    Test-MtAdDaclOuObjectCount

    Returns $true if DACL data is accessible.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdDaclOuObjectCount
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $adState = Get-MtADDomainState
    if ($null -eq $adState) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Not connected to Active Directory.'
        return $null
    }

    $daclEntries = @($adState.DaclEntries)
    $ouDaclEntries = @($daclEntries | Where-Object { $_.ObjectClass -eq 'organizationalUnit' })
    $totalDaclEntryCount = ($daclEntries | Measure-Object).Count
    $ouDaclEntryCount = ($ouDaclEntries | Measure-Object).Count
    $distinctOuObjectCount = (@(
            $ouDaclEntries |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_.ObjectDN) } |
                Select-Object -ExpandProperty ObjectDN -Unique
        ) | Measure-Object).Count

    $testResult = $true

    $result = "| Metric | Value |`n"
    $result += "| --- | --- |`n"
    $result += "| Total DACL Entries | $totalDaclEntryCount |`n"
    $result += "| OU DACL Entries | $ouDaclEntryCount |`n"
    $result += "| Distinct OU Objects With DACL Entries | $distinctOuObjectCount |`n"

    $testResultMarkdown = "Active Directory DACL data has been filtered to Organizational Unit objects. $ouDaclEntryCount DACL entr$(if ($ouDaclEntryCount -eq 1) { 'y' } else { 'ies' }) were found across $distinctOuObjectCount OU object(s).`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}


