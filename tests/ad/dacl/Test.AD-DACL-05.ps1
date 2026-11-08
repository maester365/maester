function Test-MtAdDaclDenyAceCount {
    <#
    .SYNOPSIS
    Counts deny authorization ACEs and lists affected objects and identities.

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
    [MaesterTest(
        Id = 'AD-DACL-05',
        Title = 'Deny ACEs and affected identities should be investigated',
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

    Write-Verbose "Starting Test-MtAdDaclDenyAceCount"
    if (-not (Test-MtAdDaclPlatformSupported)) {
        Add-MtTestResultDetail -SkippedBecause NotSupported
        return $null
    }
    $adState = Get-MtADDomainState -Categories @('DaclEntries')
    Write-Verbose "Retrieved AD state"
    if ($null -eq $adState -or $null -eq $adState.DaclEntries) {
        throw 'DACL data is unavailable.'
    }
    Write-Verbose "Filtering/counting dacl deny ace count"

    $daclEntries = @($adState.DaclEntries | Where-Object { $null -ne $_ })
    if ($daclEntries.Count -eq 0) {
        throw 'No DACL entries were collected; cannot assess deny ACEs.'
    }
    if (@($daclEntries | Where-Object { [string]::IsNullOrWhiteSpace($_.ObjectDN) -or [string]::IsNullOrWhiteSpace($_.AccessControlType) }).Count -gt 0) {
        throw 'DACL entries are missing object names or access control types.'
    }
    $totalDaclEntryCount = ($daclEntries | Measure-Object).Count
    $denyEntries = @($daclEntries | Where-Object { $_.AccessControlType -eq 'Deny' })
    $denyAceCount = ($denyEntries | Measure-Object).Count
    $affectedObjects = (@(
            $denyEntries |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_.ObjectDN) } |
                Select-Object -ExpandProperty ObjectDN -Unique
        ) | Measure-Object).Count

    $testResult = $true

    $result = "| Metric | Value |" + "`n"
    $result += "| --- | --- |" + "`n"
    $result += "| Total DACL Entries | $totalDaclEntryCount |" + "`n"
    $result += "| Deny ACEs | $denyAceCount |" + "`n"
    $result += "| Objects With Deny ACEs | $affectedObjects |" + "`n"
    $result += "`n| Object Name | Object Class | Object DN | Identity Reference | Deny ACE Count |`n| --- | --- | --- | --- | --- |`n"
    foreach ($group in @($denyEntries | Group-Object ObjectDN, IdentityReference | Sort-Object -Property @{ Expression = 'Count'; Descending = $true }, Name)) {
        $sample = $group.Group | Select-Object -First 1
        $objectName = ([string]$sample.ObjectName) -replace '\|', '&#124;'
        $objectClass = ([string]$sample.ObjectClass) -replace '\|', '&#124;'
        $objectDn = ([string]$sample.ObjectDN) -replace '\|', '&#124;'
        $identity = ([string]$sample.IdentityReference) -replace '\|', '&#124;'
        $result += "| $objectName | $objectClass | $objectDn | $identity | $($group.Count) |`n"
    }
    if ($denyAceCount -eq 0) {
        $result += "| No deny ACEs found | | | | 0 |`n"
    }
    Write-Verbose "Counts computed"

    $testResultMarkdown = "Active Directory DACL data has been reviewed for deny authorizations. $denyAceCount deny ACE(s) were identified across $affectedObjects object(s).`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown -Investigate
    Write-Verbose "Completed Test-MtAdDaclDenyAceCount"
    return $testResult
}
