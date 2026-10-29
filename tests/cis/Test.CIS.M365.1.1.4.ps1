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
        Mitre = 'T1566.002',
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

    if ((Get-MgContext).AuthType -ne 'Delegated') {
        Add-MtTestResultDetail -SkippedBecause NotSupportedAppPermission
    }

    Write-Verbose 'Getting administrative roles'
    $roles = Get-MtRole | Where-Object {
        $_.displayName -like '*Administrator*' -or $_.displayName -eq 'Global Reader'
    }

    $roleIds = @($roles.id)
    $roleMembers = @()
    if ($roleIds.Count -gt 0) {
        Write-Verbose 'Getting active role members'
        $roleMembers = @(Get-MtRoleMember -RoleId $roleIds -MemberStatus Active)
    }

    $administrativeUsers = @($roleMembers | Where-Object {
        $_.'@odata.type' -eq '#microsoft.graph.user'
    } | Sort-Object -Property id -Unique)

    $userIds = @($administrativeUsers.id)
    $users = @()
    if ($userIds.Count -gt 0) {
        Write-Verbose 'Requesting administrative user details'
        $users = @(Invoke-MtGraphRequest -RelativeUri 'users' -UniqueId $userIds -Select id, displayName, userPrincipalName)
    }

    $licenseFindings = [System.Collections.Generic.List[object]]::new()
    foreach ($user in $users) {
        $licenses = @(Invoke-MtGraphRequest -RelativeUri "users/$($user.id)/licenseDetails" -Select skuPartNumber)
        foreach ($license in $licenses) {
            $skuPartNumber = [string]$license.skuPartNumber
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
