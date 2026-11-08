function Test-MtAdDaclUnresolvedSidCount {
    <#
    .SYNOPSIS
    Counts unresolved SID references and lists affected objects.

    .DESCRIPTION
    This test reviews DACL entries from Get-MtADDomainState -Categories @('DaclEntries') and identifies ACEs whose
    IdentityReference still appears as a raw domain SID. These orphaned SID references
    can indicate deleted accounts, stale delegations, or incomplete cleanup after
    migrations and privilege changes.

    .EXAMPLE
    Test-MtAdDaclUnresolvedSidCount

    Returns $true if DACL data is accessible.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdDaclUnresolvedSidCount
    #>
    [MaesterTest(
        Id = 'AD-DACL-15',
        Title = 'Unresolved SID counts and affected objects should be investigated',
        Product = 'ad',
        Feature = 'permissions',
        Area = 'access-control',
        ResourceType = 'Permission',
        Severity = 'Info',
        Mitre = 'None',
        Service = 'ActiveDirectory',
        Platform = 'Windows',
        Permission = ('ActiveDirectory:Ldap:*.ntSecurityDescriptor:ReadControl'),
        LongRunning,
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Starting Test-MtAdDaclUnresolvedSidCount"

    if (-not (Test-MtAdDaclPlatformSupported)) {
        Add-MtTestResultDetail -SkippedBecause NotSupported
        return $null
    }
    $adState = Get-MtADDomainState -Categories @('DaclEntries')
    if ($null -eq $adState -or $null -eq $adState.DaclEntries) {
        throw 'DACL data is unavailable.'
    }

    $daclEntries = @($adState.DaclEntries | Where-Object { $null -ne $_ })
    if ($daclEntries.Count -eq 0) {
        throw 'No DACL entries were collected; cannot assess unresolved SIDs.'
    }
    if (@($daclEntries | Where-Object { [string]::IsNullOrWhiteSpace($_.ObjectDN) }).Count -gt 0) {
        throw 'DACL entries are missing object distinguished names.'
    }
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

    $result = '| Metric | Value |' + "`n"
    $result += '| --- | --- |' + "`n"
    $result += "| Total DACL Entries | $($daclEntries.Count) |" + "`n"
    $result += "| ACEs with Unresolved SID IdentityReference | $($unresolvedEntries.Count) |" + "`n"
    $result += "| Distinct Unresolved SIDs | $distinctUnresolvedSidCount |" + "`n"
    $result += "`n| Object DN | Distinct Unresolved SID Count | Unresolved SIDs |`n| --- | --- | --- |`n"
    foreach ($group in @($unresolvedEntries | Group-Object ObjectDN | Sort-Object -Property @{ Expression = 'Count'; Descending = $true }, Name)) {
        $objectDn = if ([string]::IsNullOrWhiteSpace($group.Name)) { '(No ObjectDN)' } else { [string]$group.Name }
        $objectDn = $objectDn -replace '\|', '&#124;'
        $sids = @($group.Group | Select-Object -ExpandProperty IdentityReference -Unique)
        $sidList = (@($sids | ForEach-Object { ([string]$_) -replace '\|', '&#124;' }) -join ', ')
        $result += "| $objectDn | $($sids.Count) | $sidList |`n"
    }
    if ($unresolvedEntries.Count -eq 0) {
        $result += "| No unresolved SID references found | 0 | |`n"
    }

    $testResultMarkdown = "Active Directory DACL identities were analyzed. $distinctUnresolvedSidCount unresolved SID reference(s) were found across $($unresolvedEntries.Count) ACE(s).`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $result

    Add-MtTestResultDetail -Result $testResultMarkdown -Investigate
    return $testResult
}
