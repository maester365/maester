function Test-MtCisSpoSharingSecurityGroup {
    <#
    .SYNOPSIS
        Ensure external sharing is restricted by security group

    .DESCRIPTION
        Checks that only members of specific security groups can share SharePoint and OneDrive content externally, or that external sharing is disabled. The test passes when SharingCapability is Disabled or either WhoCanShareAuthenticatedGuestAllowList or WhoCanShareAnonymousAllowList contains at least one group, because groups in the anonymous list can also share with authenticated guests. The legacy guest sharing group list is reported for information only.

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
    # The admin center stores the groups in the two WhoCanShare lists. Groups in the anonymous list can share with Anyone and with authenticated guests, so either list restricts external sharing.
    # The older guest sharing group list is read for information only. An empty value counts as not set.
    $allowListSettings = 'WhoCanShareAuthenticatedGuestAllowList', 'WhoCanShareAnonymousAllowList'
    $groupSettings = $allowListSettings + 'GuestSharingGroupAllowListInTenantByPrincipalIdentity'
    $groups = [ordered]@{}
    foreach ($name in $groupSettings) {
        $value = if ($spoTenant.PSObject.Properties[$name]) { $spoTenant.$name } else { $null }
        $groups[$name] = @($value | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
    }
    $hasAllowListGroup = @($allowListSettings | Where-Object { $groups[$_].Count -gt 0 }).Count -gt 0
    $isDisabled = $sharingCapability -eq 'Disabled'
    $testResult = $isDisabled -or $hasAllowListGroup

    $displayCapability = if ($null -eq $sharingCapability) { 'Not found' } else { $sharingCapability }
    $capabilityStatus = if ($isDisabled) { 'Pass' } else { 'Info' }
    $resultMarkdown = if ($testResult) {
        "Well done. Only members of a security group can share externally, or external sharing is disabled.`n`n"
    } else {
        "External sharing in SharePoint Online is not limited to members of a security group. At least one security group must be set in WhoCanShareAuthenticatedGuestAllowList or WhoCanShareAnonymousAllowList, or SharingCapability must be set to Disabled.`n`n"
    }
    $resultMarkdown += "| Setting | Value | Result |`n"
    $resultMarkdown += "| --- | --- | --- |`n"
    $rows = @("| SharingCapability | $displayCapability | $capabilityStatus |")
    foreach ($name in $groupSettings) {
        $displayGroups = if ($groups[$name].Count -eq 0) { 'Not set' } else { $groups[$name] -join ', ' }
        $rowStatus = if ($name -notin $allowListSettings) {
            'Info'
        } elseif ($groups[$name].Count -gt 0) {
            'Pass'
        } elseif ($testResult) {
            'Not required'
        } else {
            'Fail'
        }
        $rows += "| $name | $displayGroups | $rowStatus |"
    }
    $resultMarkdown += $rows -join "`n"

    Add-MtTestResultDetail -Result $resultMarkdown
    return $testResult
}
