function Test-MtAdDaclDistinctIdentityCount {
    <#
    .SYNOPSIS
    Counts distinct identities referenced by DACL ACEs.

    .DESCRIPTION
    This test retrieves cached DACL entry data from Active Directory and counts the
    number of unique identities that appear in access control entries. Reviewing the
    number of distinct identities helps identify how broadly permissions are delegated
    across directory objects.

    .EXAMPLE
    Test-MtAdDaclDistinctIdentityCount

    Returns $true if DACL data is accessible.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdDaclDistinctIdentityCount
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $adState = Get-MtADDomainState
    if ($null -eq $adState) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory
        return $null
    }

    $daclEntries = @($adState.DaclEntries)
    $totalAceCount = ($daclEntries | Measure-Object).Count
    $distinctIdentityReferences = @(
        $daclEntries |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_.IdentityReference) } |
            Select-Object -ExpandProperty IdentityReference -Unique
    )
    $distinctIdentityCount = ($distinctIdentityReferences | Measure-Object).Count
    $distinctObjectCount = @(
        $daclEntries |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_.ObjectDN) } |
            Select-Object -ExpandProperty ObjectDN -Unique
    ).Count

    $largestIdentityGroup = $daclEntries |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_.IdentityReference) } |
        Group-Object IdentityReference |
        Sort-Object -Property @{ Expression = 'Count'; Descending = $true }, @{ Expression = 'Name'; Descending = $false } |
        Select-Object -First 1

    $testResult = $true

    $result = "| Metric | Value |`n"
    $result += "| --- | --- |`n"
    $result += "| Total DACL ACEs | $totalAceCount |`n"
    $result += "| Distinct identities | $distinctIdentityCount |`n"
    $result += "| Distinct objects represented | $distinctObjectCount |`n"

    if ($null -ne $largestIdentityGroup) {
        $largestIdentityName = [string]$largestIdentityGroup.Name
        $largestIdentityName = $largestIdentityName -replace '\|', '\\&#124;'
        $result += "| Identity with most ACEs | $largestIdentityName |`n"
        $result += "| ACEs for most represented identity | $($largestIdentityGroup.Count) |`n"
    }

    $testResultMarkdown = "This informational test summarizes how many unique identities are present across collected DACL ACEs.`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
