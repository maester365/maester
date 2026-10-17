function Test-MtCisSpoSharingSecurityGroup {
    <#
    .SYNOPSIS
        Ensure external sharing is restricted by security group

    .DESCRIPTION
        Checks that only members of specific security groups can share SharePoint and OneDrive content
        with external users, or that external sharing is turned off. The test reads the two WhoCanShare
        group lists that the admin center writes, and the older guest sharing group list.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (7.2.8, L2)

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
    $hasSecurityGroup = @($groups.Values | Where-Object { $_.Count -gt 0 }).Count -gt 0
    $testResult = $hasSecurityGroup -or ($sharingCapability -eq 'Disabled')

    $displayCapability = if ($null -eq $sharingCapability) { 'Not found' } else { $sharingCapability }
    $status = if ($testResult) { 'Pass' } else { 'Fail' }
    $resultMarkdown = if ($testResult) {
        "Well done. Only members of a security group can share externally, or external sharing is disabled.`n`n"
    } else {
        "External sharing in SharePoint Online is not limited to members of a security group.`n`n"
    }
    $resultMarkdown += "| Setting | Value | Result |`n"
    $resultMarkdown += "| --- | --- | --- |`n"
    $rows = @("| SharingCapability | $displayCapability | $status |")
    foreach ($name in $groupSettings) {
        $displayGroups = if ($groups[$name].Count -eq 0) { 'Not set' } else { $groups[$name] -join ', ' }
        $rows += "| $name | $displayGroups | $status |"
    }
    $resultMarkdown += $rows -join "`n"

    Add-MtTestResultDetail -Result $resultMarkdown
    return $testResult
}
