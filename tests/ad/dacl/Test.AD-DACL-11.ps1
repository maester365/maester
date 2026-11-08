function Test-MtAdDaclPrivilegedExtendedRightCount {
    <#
    .SYNOPSIS
    Counts ExtendedRight allow ACEs and lists right types and identities.

    .DESCRIPTION
    This test reviews DACL entries and counts allow ACEs that include the
    ExtendedRight permission. Extended rights can delegate powerful object-specific
    operations and should be understood within the context of directory delegation.

    .EXAMPLE
    Test-MtAdDaclPrivilegedExtendedRightCount

    Returns $true if DACL data is accessible.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdDaclPrivilegedExtendedRightCount
    #>
    [MaesterTest(
        Id = 'AD-DACL-11',
        Title = 'ExtendedRight delegations and identities should be investigated',
        Product = 'ad',
        Feature = 'permissions',
        Area = 'privileged-access',
        ResourceType = 'Permission',
        Severity = 'Info',
        Mitre = ('T1003.006', 'T1098'),
        Service = 'ActiveDirectory',
        Platform = 'Windows',
        Permission = ('ActiveDirectory:Ldap:*.ntSecurityDescriptor:ReadControl'),
        LongRunning,
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Starting Test-MtAdDaclPrivilegedExtendedRightCount"
    if (-not (Test-MtAdDaclPlatformSupported)) {
        Add-MtTestResultDetail -SkippedBecause NotSupported
        return $null
    }
    $adState = Get-MtADDomainState -Categories @('DaclEntries')
    Write-Verbose "Retrieved AD state"
    if ($null -eq $adState -or $null -eq $adState.DaclEntries) {
        throw 'DACL data is unavailable.'
    }
    Write-Verbose "Filtering/counting dacl privileged extended right count"

    $daclEntries = @($adState.DaclEntries | Where-Object { $null -ne $_ })
    if ($daclEntries.Count -eq 0) {
        throw 'No DACL entries were collected; cannot assess extended rights.'
    }
    if (@($daclEntries | Where-Object { [string]::IsNullOrWhiteSpace($_.ObjectDN) -or [string]::IsNullOrWhiteSpace($_.AccessControlType) -or [string]::IsNullOrWhiteSpace($_.ActiveDirectoryRights) }).Count -gt 0) {
        throw 'DACL entries are missing object names, access control types or rights.'
    }
    $extendedRightEntries = @(
        $daclEntries | Where-Object {
            $_.AccessControlType -eq 'Allow' -and
            [string]$_.ActiveDirectoryRights -match '(^|,\s*)ExtendedRight(,|$)'
        }
    )

    $normalizedObjectTypes = @(
        foreach ($entry in $extendedRightEntries) {
            if ([string]::IsNullOrWhiteSpace($entry.ObjectType) -or $entry.ObjectType -eq '00000000-0000-0000-0000-000000000000') {
                'All / Not specified'
            }
            else {
                [string]$entry.ObjectType
            }
        }
    )

    $testResult = $true

    $result = "| Metric | Value |" + "`n"
    $result += "| --- | --- |" + "`n"
    $result += "| Total DACL ACEs | $((@($daclEntries) | Measure-Object).Count) |" + "`n"
    $result += "| ExtendedRight allow ACEs | $($extendedRightEntries.Count) |" + "`n"
    $result += "| Distinct ObjectType values | $(@($normalizedObjectTypes | Sort-Object -Unique).Count) |" + "`n"
    $result += "| Distinct identities with ExtendedRight | $(@($extendedRightEntries | Where-Object { -not [string]::IsNullOrWhiteSpace($_.IdentityReference) } | Select-Object -ExpandProperty IdentityReference -Unique).Count) |" + "`n"
    $result += "| Distinct objects with ExtendedRight | $(@($extendedRightEntries | Where-Object { -not [string]::IsNullOrWhiteSpace($_.ObjectDN) } | Select-Object -ExpandProperty ObjectDN -Unique).Count) |" + "`n"
    $result += "`n| ObjectType | ACE Count | Distinct Objects | Distinct Identities |`n| --- | --- | --- | --- |`n"
    $typedEntries = @(
        foreach ($entry in $extendedRightEntries) {
            [PSCustomObject]@{
                ObjectType = if ([string]::IsNullOrWhiteSpace($entry.ObjectType) -or $entry.ObjectType -eq '00000000-0000-0000-0000-000000000000') { 'All / Not specified' } else { [string]$entry.ObjectType }
                ObjectDN = $entry.ObjectDN
                IdentityReference = $entry.IdentityReference
            }
        }
    )
    foreach ($group in @($typedEntries | Group-Object ObjectType | Sort-Object -Property @{ Expression = 'Count'; Descending = $true }, Name)) {
        $objectType = ([string]$group.Name) -replace '\|', '&#124;'
        $objects = @($group.Group | Where-Object { -not [string]::IsNullOrWhiteSpace($_.ObjectDN) } | Select-Object -ExpandProperty ObjectDN -Unique).Count
        $identities = @($group.Group | Where-Object { -not [string]::IsNullOrWhiteSpace($_.IdentityReference) } | Select-Object -ExpandProperty IdentityReference -Unique).Count
        $result += "| $objectType | $($group.Count) | $objects | $identities |`n"
    }
    if ($typedEntries.Count -eq 0) {
        $result += "| No ExtendedRight allow ACEs found | 0 | 0 | 0 |`n"
    }

    # The GUID list formerly used by AD-DACL-13 identifies sensitive extended rights for identity review.
    $privilegedExtendedRights = @{
        '440820ad-65b4-11d1-a3da-0000f875ae0d' = 'Add GUID'
        'e2a36dc9-ae17-47c3-b58b-be34c55ba633' = 'Create Inbound Forest Trust'
        '3e0f7e18-4434-48c6-a534-0b62eb6d8b2c' = 'DS-Clone-Domain-Controller'
        '2f16c4a5-b98e-432c-952a-cb388ba33f2e' = 'DS-Execute-Intentions-Script'
        '9923a32a-3607-11d2-b9be-0000f87a36b2' = 'DS-Install-Replica'
        '1131f6aa-9c07-11d1-f79f-00c04fc2dcd2' = 'DS-Replication-Get-Changes'
        '1131f6ad-9c07-11d1-f79f-00c04fc2dcd2' = 'DS-Replication-Get-Changes-All'
        '89e95b76-444d-4c62-991a-0facbeda640c' = 'DS-Replication-Get-Changes-In-Filtered-Set'
        '1131f6ac-9c07-11d1-f79f-00c04fc2dcd2' = 'DS-Replication-Manage-Topology'
        '05c74c5e-4deb-43b5-bc7c-0dfc1ed58fbd' = 'Enable Per User Reversibly Encrypted Password'
        '7c0e2a7c-a419-48e4-a995-10180aad54dd' = 'Manage-Optional-Features'
        'ba33815a-4f93-4c76-87f3-57574bff8109' = 'Migrate SID History'
        '4b6e08c2-a6b3-11d0-afd3-00c04fd930c9' = 'msmq-Open-Connector'
        '06bd3201-df3e-11d1-9c86-006008764d0e' = 'msmq-Peek'
        '4b6e08c3-a6b3-11d0-afd3-00c04fd930c9' = 'msmq-Peek-computer-Journal'
        '4b6e08c4-a6b3-11d0-afd3-00c04fd930c9' = 'msmq-Peek-Dead-Letter'
        '06bd3200-df3e-11d1-9c86-006008764d0e' = 'msmq-Receive'
        '4b6e08c5-a6b3-11d0-afd3-00c04fd930c9' = 'msmq-Receive-computer-Journal'
        '4b6e08c6-a6b3-11d0-afd3-00c04fd930c9' = 'msmq-Receive-Dead-Letter'
        '06bd3203-df3e-11d1-9c86-006008764d0e' = 'msmq-Receive-journal'
        '06bd3202-df3e-11d1-9c86-006008764d0e' = 'msmq-Send'
        '1131f6ae-9c07-11d1-f79f-00c04fc2dcd2' = 'Read Only Replication Secret Synchronization'
        '45ec5156-db7e-47bb-b53f-dbeb2d03c40f' = 'Reanimate Tombstones'
        '62dd28a8-7f46-11d2-b9ad-00c04f79f805' = 'Recalculate Security Inheritance'
        'ab721a56-1e2f-11d0-9819-00aa0040529b' = 'Receive As'
        '7726b9d5-a4b4-4288-a6b2-dce952e80a7f' = 'Run Protect Admin Groups Task'
        '91d67418-0135-4acc-8d79-c08e857cfbec' = 'Enumerate Entire SAM Domain'
        'ab721a54-1e2f-11d0-9819-00aa0040529b' = 'Send As'
        'ccc2dc7d-a6ad-4a7a-8846-c04e3cc53501' = 'Unexpire Password'
        '280f369c-67c7-438e-ae98-1d46f3f5c52f' = 'Update Password Not Required Bit'
        'ab721a53-1e2f-11d0-9819-00aa0040529b' = 'Change Password'
        '00299570-246d-11d0-a768-00aa006e0529' = 'Reset Password'
    }
    $sensitiveEntries = @($extendedRightEntries | Where-Object {
        -not [string]::IsNullOrWhiteSpace($_.IdentityReference) -and
        -not [string]::IsNullOrWhiteSpace($_.ObjectType) -and
        $privilegedExtendedRights.ContainsKey(([string]$_.ObjectType).ToLowerInvariant())
    })
    $result += "`n| Identity Reference | Privileged Extended Rights | ACE Count |`n| --- | --- | --- |`n"
    foreach ($group in @($sensitiveEntries | Group-Object IdentityReference | Sort-Object -Property @{ Expression = 'Count'; Descending = $true }, Name)) {
        $identity = ([string]$group.Name) -replace '\|', '&#124;'
        $rights = @($group.Group | ForEach-Object { $privilegedExtendedRights[([string]$_.ObjectType).ToLowerInvariant()] } | Sort-Object -Unique) -join ', '
        $result += "| $identity | $rights | $($group.Count) |`n"
    }
    if ($sensitiveEntries.Count -eq 0) {
        $result += "| No named privileged extended rights found | | 0 |`n"
    }
    Write-Verbose "Counts computed"

    $testResultMarkdown = "This informational test counts ExtendedRight allow ACEs and groups them by ObjectType and by identities holding named sensitive rights.`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown -Investigate
    Write-Verbose "Completed Test-MtAdDaclPrivilegedExtendedRightCount"
    return $testResult
}
