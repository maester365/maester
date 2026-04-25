function Test-MtAdDaclPrivilegedExtendedRightIdentity {
    <#
    .SYNOPSIS
    Returns identities with privileged extended rights in Active Directory DACLs.

    .DESCRIPTION
    This test analyzes DACL entries collected by Get-MtADDomainState and identifies
    identities that are granted privileged extended rights through allow ACEs.
    Extended rights such as password reset and replication-related permissions can
    enable sensitive directory operations and should be tightly controlled.

    .EXAMPLE
    Test-MtAdDaclPrivilegedExtendedRightIdentity

    Returns $true if DACL data is accessible.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdDaclPrivilegedExtendedRightIdentity
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

    $privilegedEntries = @(
        $daclEntries | Where-Object {
            $_.AccessControlType -eq 'Allow' -and
            $_.ActiveDirectoryRights -eq 'ExtendedRight' -and
            -not [string]::IsNullOrWhiteSpace([string]$_.IdentityReference) -and
            -not [string]::IsNullOrWhiteSpace([string]$_.ObjectType) -and
            $privilegedExtendedRights.ContainsKey(([string]$_.ObjectType).ToLowerInvariant())
        }
    )

    $identityGroups = @(
        $privilegedEntries |
            Group-Object -Property IdentityReference |
            Sort-Object @{ Expression = 'Count'; Descending = $true }, @{ Expression = 'Name'; Descending = $false }
    )

    $result = '| IdentityReference | Privileged Extended Rights | ACE Count |`n'
    $result += '| --- | --- | --- |`n'

    foreach ($group in $identityGroups) {
        $identity = [string]$group.Name
        $identity = $identity -replace '\|', '\\&#124;'

        $rights = @(
            $group.Group |
                ForEach-Object { $privilegedExtendedRights[([string]$_.ObjectType).ToLowerInvariant()] } |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
                Sort-Object -Unique
        )

        $rightList = ($rights | ForEach-Object { $_ -replace '\|', '\\&#124;' }) -join ', '
        $result += "| $identity | $rightList | $($group.Count) |`n"
    }

    $testResult = $true
    $testResultMarkdown = "Active Directory DACL entries were analyzed for privileged extended rights. $($identityGroups.Count) identity reference(s) have at least one privileged extended right ACE.`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $result

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
