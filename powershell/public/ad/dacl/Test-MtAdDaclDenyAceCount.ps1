function Test-MtAdDaclDenyAceCount {
    <#
    .SYNOPSIS
    Counts deny authorization ACEs in collected DACL data.

    .DESCRIPTION
    This informational test reviews collected Active Directory DACL data and counts ACEs where the
    access control type contains Deny. Deny ACEs are security-significant because they can override
    allow permissions and affect delegated administration, object visibility, or operational access
    in unexpected ways.

    .EXAMPLE
    Test-MtAdDaclDenyAceCount

    Returns $true if DACL data is accessible.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdDaclDenyAceCount
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Starting Test-MtAdDaclDenyAceCount"
    $adState = Get-MtADDomainState
    Write-Verbose "Retrieved AD state"
    if ($null -eq $adState) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Not connected to Active Directory.'
        return $null
    }
    Write-Verbose "Filtering/counting dacl deny ace count"

    $daclEntries = @($adState.DaclEntries)
    $totalDaclEntryCount = ($daclEntries | Measure-Object).Count
    $denyEntries = @($daclEntries | Where-Object { $_.AccessControlType -match 'Deny' })
    $denyAceCount = ($denyEntries | Measure-Object).Count
    $affectedObjects = (@(
            $denyEntries |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_.ObjectDN) } |
                Select-Object -ExpandProperty ObjectDN -Unique
        ) | Measure-Object).Count

    $testResult = $true

    $result = "| Metric | Value |`n"
    $result += "| --- | --- |`n"
    $result += "| Total DACL Entries | $totalDaclEntryCount |`n"
    $result += "| Deny ACEs | $denyAceCount |`n"
    $result += "| Objects With Deny ACEs | $affectedObjects |`n"
    Write-Verbose "Counts computed"

    $testResultMarkdown = "Active Directory DACL data has been reviewed for deny authorizations. $denyAceCount deny ACE(s) were identified across $affectedObjects object(s).`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown
    Write-Verbose "Completed Test-MtAdDaclDenyAceCount"
    return $testResult
}


