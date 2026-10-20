function Test-MtCisSpoSharingSecurityGroup {
    <#
    .SYNOPSIS
        Ensure external sharing is restricted by security group

    .DESCRIPTION
        Checks that only members of specific security groups can share SharePoint and OneDrive content externally, or that external sharing is disabled. The test passes when SharingCapability is Disabled or WhoCanShareAuthenticatedGuestAllowList contains at least one group, as defined by the CIS audit procedure. The anonymous and legacy guest sharing group lists are reported for information only.

    .EXAMPLE
        Test-MtCisSpoSharingSecurityGroup

        Returns true if only members of a security group can share externally, or external sharing is disabled.

    .LINK
        https://maester.dev/docs/commands/Test-MtCisSpoSharingSecurityGroup
    #>
    [MaesterTest(
        Id = 'CIS.M365.7.2.8',
        Title = 'Ensure external sharing is restricted by security group',
        Product = 'sharepoint',
        Feature = 'external-sharing',
        Area = 'external-access',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Medium',
        ImplementationCost = 'Medium',
        Mitre = ('T1213.002', 'T1530'),
        Control = ('cis-m365:7.2.8', 'nist-800-53-r5:AC-21'),
        Service = 'SharePointOnline',
        Author = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Test-MtCisSpoSharingSecurityGroup: Checking the sharing capability and the security groups that can share externally'
    $spoTenant = Get-MtSpo
    $sharingCapability = $spoTenant.SharingCapability
    # The admin center stores the groups in the two WhoCanShare lists. The older setting is read as well.
    # An empty value counts as not set.
    $groupSettings = 'WhoCanShareAuthenticatedGuestAllowList', 'WhoCanShareAnonymousAllowList', 'GuestSharingGroupAllowListInTenantByPrincipalIdentity'
    $groups = [ordered]@{}
    foreach ($name in $groupSettings) {
        $groups[$name] = @($spoTenant.$name | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
    }
    $authList = $groups['WhoCanShareAuthenticatedGuestAllowList']
    $testResult = ($sharingCapability -eq 'Disabled') -or ($authList.Count -gt 0)

    $displayCapability = if ($null -eq $sharingCapability) { 'Not found' } else { $sharingCapability }
    $capabilityStatus = if ($sharingCapability -eq 'Disabled') { 'Pass' } else { 'Info' }
    $authenticatedStatus = if ($authList.Count -gt 0) {
        'Pass'
    } elseif ($sharingCapability -eq 'Disabled') {
        'Pass (not required)'
    } else {
        'Fail'
    }
    $resultMarkdown = if ($testResult) {
        "Well done. Only members of a security group can share externally, or external sharing is disabled.`n`n"
    } else {
        "External sharing in SharePoint Online is not limited to members of a security group. CIS 7.2.8 requires at least one security group in WhoCanShareAuthenticatedGuestAllowList, or SharingCapability set to Disabled.`n`n"
    }
    $resultMarkdown += "| Setting | Value | Result |`n"
    $resultMarkdown += "| --- | --- | --- |`n"
    $rows = @("| SharingCapability | $displayCapability | $capabilityStatus |")
    foreach ($name in $groupSettings) {
        $displayGroups = if ($groups[$name].Count -eq 0) { 'Not set' } else { $groups[$name] -join ', ' }
        $rowStatus = if ($name -eq 'WhoCanShareAuthenticatedGuestAllowList') { $authenticatedStatus } else { 'Info' }
        $rows += "| $name | $displayGroups | $rowStatus |"
    }
    $resultMarkdown += $rows -join "`n"

    Add-MtTestResultDetail -Result $resultMarkdown
    return $testResult
}
