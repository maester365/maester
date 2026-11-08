function ConvertTo-MtAdSpnSidText {
    [CmdletBinding()]
    [OutputType([string])]
    param([object] $Sid)

    if ($null -eq $Sid) { return '' }
    if ($Sid.PSObject.Properties['Value'] -and $null -ne $Sid.Value) {
        return [string]$Sid.Value
    }
    return [string]$Sid
}

function Test-MtAdUserSpnDomainAdminCount {
    <#
    .SYNOPSIS
    Counts SPNs configured on domain administrator accounts.

    .DESCRIPTION
    This test retrieves all Service Principal Names (SPNs) configured on domain
    administrator accounts. Domain admin accounts with SPNs are extremely high-risk
    targets for Kerberoasting attacks as they typically have the highest privileges.

    .EXAMPLE
    Test-MtAdUserSpnDomainAdminCount

    Returns $true if SPN data is accessible, $false otherwise.
    The test result includes the count of SPNs on domain admin accounts.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdUserSpnDomainAdminCount
    #>
    [MaesterTest(
        Id = 'AD-SPN-12',
        Title = 'No domain admin accounts should have SPNs configured',
        Product = 'ad',
        Feature = 'service-principal-names',
        Area = 'privileged-access',
        ResourceType = 'User',
        Severity = 'Critical',
        UserImpact = 'Low',
        ImplementationCost = 'Medium',
        Mitre = 'T1558.003',
        Control = ('nist-800-53-r5:AC-6(5)', 'nist-800-53-r5:IA-5'),
        Service = 'ActiveDirectory',
        Permission = ('ActiveDirectory:Ldap:domainDNS:ReadProperty', 'ActiveDirectory:Ldap:group:ReadProperty', 'ActiveDirectory:Ldap:group.member:ReadProperty', 'ActiveDirectory:Ldap:user:ReadProperty'),
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Starting Test-MtAdUserSpnDomainAdminCount"

    # Get AD domain state data (uses cached data if available)
    $adState = Get-MtADDomainState -Categories @('Domain', 'Groups', 'Users')

    if ($null -eq $adState) {
        throw 'Domain, groups and users are unavailable; cannot assess Domain Admins.'
    }

    $users = $adState.Users
    $domainSid = ConvertTo-MtAdSpnSidText -Sid $adState.Domain.DomainSID
    if (-not $domainSid -or $null -eq $adState.Groups -or $null -eq $users -or @($users).Count -eq 0) {
        throw 'Domain SID, groups or users are unavailable; cannot assess Domain Admins.'
    }
    $adminGroup = @($adState.Groups | Where-Object { (ConvertTo-MtAdSpnSidText -Sid $_.SID) -eq "$domainSid-512" })
    if ($adminGroup.Count -ne 1) { throw 'Unable to identify the Domain Admins group by its domain SID and RID 512.' }
    $connection = New-MtAdProtocolConnection -ProtocolEvidence $adState.ProtocolEvidence
    try {
        $members = @(Get-MtLdapGroupMember -Connection $connection -GroupDistinguishedName $adminGroup[0].DistinguishedName)
    }
    finally {
        $connection.Dispose()
    }
    # Expand nested groups from the cached domain group collection; unresolved or foreign members
    # must not produce a clean result when their user SPNs cannot be assessed.
    $pending = [System.Collections.Generic.Queue[object]]::new()
    foreach ($member in $members) { $pending.Enqueue($member) }
    $visitedGroups = @{ ([string]$adminGroup[0].DistinguishedName) = $true }
    $memberSids = @{}
    $userDns = @{}
    foreach ($user in $users) {
        $userSid = ConvertTo-MtAdSpnSidText -Sid $user.SID
        if ([string]::IsNullOrWhiteSpace($userSid)) {
            throw "User has no SID: $($user.DistinguishedName)"
        }
        $userDns[[string]$user.DistinguishedName] = $user
        # AD primary-group membership is not recorded in the group's member attribute.
        if ($user.PrimaryGroupId -eq 512 -and $userSid.StartsWith("$domainSid-")) {
            $memberSids[$userSid] = $true
        }
    }
    $connection = New-MtAdProtocolConnection -ProtocolEvidence $adState.ProtocolEvidence
    try {
        while ($pending.Count -gt 0) {
            $member = $pending.Dequeue()
            $memberSid = ConvertTo-MtAdSpnSidText -Sid $member.SID
            $nestedGroup = @($adState.Groups | Where-Object { $_.DistinguishedName -eq $member.DistinguishedName })
            if ($nestedGroup.Count -gt 0) {
                $dn = [string]$nestedGroup[0].DistinguishedName
                if (-not $visitedGroups.ContainsKey($dn)) {
                    $visitedGroups[$dn] = $true
                    foreach ($child in @(Get-MtLdapGroupMember -Connection $connection -GroupDistinguishedName $dn)) { $pending.Enqueue($child) }
                }
            }
            elseif ($userDns.ContainsKey([string]$member.DistinguishedName)) {
                if (-not $memberSid) { throw "Domain Admins member has no SID: $($member.DistinguishedName)" }
                $memberSids[$memberSid] = $true
            }
            else { throw "Unresolved Domain Admins member: $($member.DistinguishedName)" }
        }
    }
    finally { $connection.Dispose() }
    $domainAdmins = @($users | Where-Object { $memberSids.ContainsKey((ConvertTo-MtAdSpnSidText -Sid $_.SID)) })
    if ($domainAdmins.Count -eq 0) {
        throw 'No Domain Admins users could be resolved from group membership or primary group ID 512.'
    }

    # Extract SPNs from domain admin accounts
    $adminSpns = $domainAdmins | Where-Object { $null -ne $_.servicePrincipalName } | ForEach-Object {
        $admin = $_
        $admin.servicePrincipalName | ForEach-Object {
            [PSCustomObject]@{
                SPN = $_
                AdminAccount = $admin.SamAccountName
                AdminSID = $admin.SID
            }
        }
    }

    $totalAdminSpns = ($adminSpns | Measure-Object).Count
    $adminsWithSpns = @($domainAdmins | Where-Object { @($_.servicePrincipalName | Where-Object { $_ }).Count -gt 0 }).Count
    $totalDomainAdmins = ($domainAdmins | Measure-Object).Count

    # Test passes if no domain admin accounts have SPNs configured
    $testResult = $totalAdminSpns -eq 0

    # Generate markdown results
    if ($null -ne $domainAdmins) {
        $result = "| Metric | Value |" + "`n"
        $result += "| --- | --- |" + "`n"
        $result += "| Domain Admin Accounts | $totalDomainAdmins |" + "`n"
        $result += "| Domain Admins with SPNs | $adminsWithSpns |" + "`n"
        $result += "| Total SPNs on Domain Admins | $totalAdminSpns |" + "`n"

        if ($totalDomainAdmins -gt 0) {
            $percentage = [Math]::Round(($adminsWithSpns / $totalDomainAdmins) * 100, 2)
            $result += "| Percentage with SPNs | $percentage% |" + "`n"
        }

        if ($totalAdminSpns -gt 0) {
            $result += "`n**⚠️ Warning**: Domain administrator accounts have SPNs configured. This is a critical security risk for Kerberoasting attacks." + "`n" + "`n"
            $result += "### Domain Admin Accounts with SPNs" + "`n" + "`n"
            $result += "| Account | SPN Count |" + "`n"
            $result += "| --- | --- |" + "`n"

            $adminGroups = $adminSpns | Group-Object AdminAccount
            foreach ($group in $adminGroups) {
                $result += "| $($group.Name) | $($group.Count) |" + "`n"
            }
        } else {
            $result += "`n**✅ Good**: No domain administrator accounts have SPNs configured." + "`n"
        }

        $testResultMarkdown = "Active Directory domain administrator SPN analysis.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
