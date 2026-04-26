function Test-MtAdDaclPrivilegedExtendedRightDetails {
    <#
    .SYNOPSIS
    Returns a breakdown of ExtendedRight allow ACEs by ObjectType.

    .DESCRIPTION
    This test reviews DACL entries, filters to allow ACEs that include the
    ExtendedRight permission, and groups them by ObjectType GUID. This helps identify
    which extended rights are most commonly delegated in the environment.

    .EXAMPLE
    Test-MtAdDaclPrivilegedExtendedRightDetails

    Returns $true if DACL data is accessible.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdDaclPrivilegedExtendedRightDetails
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
    $extendedRightEntries = @(
        foreach ($entry in $daclEntries) {
            if ($entry.AccessControlType -like 'AccessAllowed*' -and [string]$entry.ActiveDirectoryRights -match '(^|,\s*)ExtendedRight(,|$)') {
                [PSCustomObject]@{
                    ObjectType = if ([string]::IsNullOrWhiteSpace($entry.ObjectType) -or $entry.ObjectType -eq '00000000-0000-0000-0000-000000000000') {
                        'All / Not specified'
                    }
                    else {
                        [string]$entry.ObjectType
                    }
                    ObjectDN = $entry.ObjectDN
                    IdentityReference = $entry.IdentityReference
                }
            }
        }
    )

    $breakdown = @(
        $extendedRightEntries |
            Group-Object ObjectType |
            Sort-Object -Property @{ Expression = 'Count'; Descending = $true }, @{ Expression = 'Name'; Descending = $false } |
            ForEach-Object {
                $entriesForType = @($_.Group)
                [PSCustomObject]@{
                    ObjectType = $_.Name
                    AceCount = $_.Count
                    DistinctObjectCount = @(
                        $entriesForType |
                            Where-Object { -not [string]::IsNullOrWhiteSpace($_.ObjectDN) } |
                            Select-Object -ExpandProperty ObjectDN -Unique
                    ).Count
                    DistinctIdentityCount = @(
                        $entriesForType |
                            Where-Object { -not [string]::IsNullOrWhiteSpace($_.IdentityReference) } |
                            Select-Object -ExpandProperty IdentityReference -Unique
                    ).Count
                }
            }
    )

    $testResult = $true

    $table = "| ObjectType | ACE Count | Distinct Objects | Distinct Identities |`n"
    $table += "| --- | --- | --- | --- |`n"

    foreach ($item in $breakdown) {
        $objectType = [string]$item.ObjectType
        $objectType = $objectType -replace '\|', '\\&#124;'
        $table += "| $objectType | $($item.AceCount) | $($item.DistinctObjectCount) | $($item.DistinctIdentityCount) |`n"
    }

    if ($breakdown.Count -eq 0) {
        $table += "| No ExtendedRight allow ACEs found | 0 | 0 | 0 |`n"
    }

    $testResultMarkdown = "This informational test groups ExtendedRight allow ACEs by ObjectType GUID.`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $table

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}


