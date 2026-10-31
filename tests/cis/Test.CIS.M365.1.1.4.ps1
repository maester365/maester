function Test-MtCisAdminLicenseFootprint {
    <#
    .SYNOPSIS
    Checks that active administrative accounts do not have application licenses.

    .DESCRIPTION
    Ensure administrative accounts use licenses with a reduced application footprint.
    CIS Microsoft 365 Foundations Benchmark v7.0.0 (1.1.4, L1)

    .EXAMPLE
    Test-MtCisAdminLicenseFootprint

    Returns true when active administrative accounts are unlicensed or use approved identity-only licenses.

    .LINK
    https://maester.dev/docs/commands/Test-MtCisAdminLicenseFootprint
    #>
    [MaesterTest(
        Id = 'CIS.M365.1.1.4',
        Title = 'Ensure administrative accounts use licenses with a reduced application footprint',
        Product = 'microsoft-365',
        RelatedProduct = 'entra',
        Feature = 'administrative-accounts',
        Area = 'privileged-access',
        ResourceType = 'User',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Medium',
        Mitre = 'T1566',
        Control = ('cis-m365:1.1.4', 'nist-800-53-r5:AC-6(5)'),
        Service = 'Graph',
        Permission = ('Graph:Scope:RoleManagement.Read.Directory|Graph:Scope:RoleManagement.Read.All', 'Graph:Scope:Directory.Read.All'),
        Author = 'NZLostboy'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # License SKU part numbers without user-facing applications that administrators may keep.
        [string[]] $AllowedLicenseSkuPartNumbers = @('AAD_PREMIUM', 'AAD_PREMIUM_P2')
    )

    Write-Verbose 'Getting administrative roles'
    $roles = Get-MtRole | Where-Object {
        $_.displayName -like '*Administrator*' -or $_.displayName -eq 'Global Reader'
    }

    $roleIds = @($roles.id)
    $roleMembers = @()
    if ($roleIds.Count -gt 0) {
        Write-Verbose 'Getting active role members'
        $roleMembers = @(Get-MtDirectoryRoleMember -RoleId $roleIds -MemberStatus Active)
    }

    $administrativeUsers = @($roleMembers | Where-Object {
        $_.'@odata.type' -eq '#microsoft.graph.user'
    } | Sort-Object -Property id -Unique)

    $userIds = @($administrativeUsers | ForEach-Object { [string]$_.id })
    $users = @()
    $skuPartNumbersById = @{}
    if ($userIds.Count -gt 0) {
        Write-Verbose 'Requesting administrative user details'
        $users = @(Invoke-MtGraphRequest -RelativeUri 'users' -UniqueId $userIds -Select id, displayName, userPrincipalName, assignedLicenses)

        $returnedUserIds = @($users | ForEach-Object { [string]$_.id })
        $missingUserIds = @($userIds | Where-Object { $_ -notin $returnedUserIds })
        if ($missingUserIds.Count -gt 0) {
            throw "Microsoft Graph did not return user details for all active administrative role members. Missing user IDs: $($missingUserIds -join ', ')."
        }

        $usersMissingAssignedLicenses = @($users | Where-Object {
            $_.PSObject.Properties.Name -notcontains 'assignedLicenses'
        })
        if ($usersMissingAssignedLicenses.Count -gt 0) {
            $missingAssignedLicenseIds = @($usersMissingAssignedLicenses | ForEach-Object { [string]$_.id })
            throw "Microsoft Graph did not return assignedLicenses for active administrative role members: $($missingAssignedLicenseIds -join ', ')."
        }

        $skuIds = @(
            $users |
            ForEach-Object { $_.assignedLicenses } |
            Where-Object { $null -ne $_ } |
            ForEach-Object { [string]$_.skuId } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            Sort-Object -Unique
        )
        if ($skuIds.Count -gt 0) {
            Write-Verbose 'Requesting subscribed SKU details'
            $subscribedSkus = @(Invoke-MtGraphRequest -RelativeUri 'subscribedSkus' -Select skuId, skuPartNumber)
            foreach ($subscribedSku in $subscribedSkus) {
                if (-not [string]::IsNullOrWhiteSpace([string]$subscribedSku.skuId)) {
                    $skuPartNumbersById[[string]$subscribedSku.skuId] = [string]$subscribedSku.skuPartNumber
                }
            }
        }
    }

    $licenseFindings = [System.Collections.Generic.List[object]]::new()
    foreach ($user in $users) {
        $licenses = @($user.assignedLicenses | Where-Object { $null -ne $_ })
        foreach ($license in $licenses) {
            $skuId = [string]$license.skuId
            $skuPartNumber = [string]$skuPartNumbersById[$skuId]
            if ([string]::IsNullOrWhiteSpace($skuPartNumber)) {
                $skuPartNumber = "Unknown SKU ($skuId)"
            }
            if ([string]::IsNullOrWhiteSpace($skuPartNumber) -or $skuPartNumber -notin $AllowedLicenseSkuPartNumbers) {
                $null = $licenseFindings.Add([pscustomobject]@{
                    DisplayName        = $user.displayName
                    UserPrincipalName  = $user.userPrincipalName
                    LicenseSkuPartNumber = $skuPartNumber
                })
            }
        }
    }

    if ($licenseFindings.Count -eq 0) {
        Add-MtTestResultDetail -Result 'Well done. Active administrative accounts are unlicensed or use only approved identity licenses.'
        return $true
    }

    $result = "These active administrative accounts have licenses outside the approved identity-only list:`n`n"
    $result += "| Display Name | User Principal Name | License SKU |`n"
    $result += "| --- | --- | --- |`n"
    foreach ($finding in $licenseFindings) {
        $result += "| $(Get-MtSafeMarkdown $finding.DisplayName) | $(Get-MtSafeMarkdown $finding.UserPrincipalName) | $(Get-MtSafeMarkdown $finding.LicenseSkuPartNumber) |`n"
    }

    Add-MtTestResultDetail -Result $result
    return $false
}
