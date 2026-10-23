function Test-MtCisSpoSharingSecurityGroup {
    <#
    .SYNOPSIS
        Ensure external sharing is restricted by security group

    .DESCRIPTION
        Checks that only members of specific security groups can share SharePoint and OneDrive content externally, or that external sharing is disabled. The test passes when SharingCapability is Disabled or WhoCanShareAuthenticatedGuestAllowList contains at least one group, as in the CIS PowerShell audit. Groups in WhoCanShareAnonymousAllowList can also share Anyone links, which need no sign-in, so they do not satisfy the control on their own. The legacy guest sharing group list is reported for information only.

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
    # The admin center stores each group in one of two lists, by its "Can share with" choice. Only the authenticated
    # guest list satisfies the control: groups in the anonymous list can also share Anyone links, which need no sign-in.
    # The anonymous list and the older guest sharing group list are read for information only. An empty value counts as not set.
    $requiredSetting = 'WhoCanShareAuthenticatedGuestAllowList'
    $anonymousSetting = 'WhoCanShareAnonymousAllowList'
    $groupSettings = $requiredSetting, $anonymousSetting, 'GuestSharingGroupAllowListInTenantByPrincipalIdentity'
    $groups = [ordered]@{}
    foreach ($name in $groupSettings) {
        $value = if ($spoTenant.PSObject.Properties[$name]) { $spoTenant.$name } else { $null }
        $groups[$name] = @($value | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
    }
    $isDisabled = $sharingCapability -eq 'Disabled'
    $testResult = $isDisabled -or $groups[$requiredSetting].Count -gt 0

    $displayCapability = if ($null -eq $sharingCapability) { 'Not found' } else { $sharingCapability }
    $capabilityStatus = if ($isDisabled) { 'Pass' } else { 'Info' }
    $resultMarkdown = if ($testResult) {
        "Well done. Only members of a security group can share externally, or external sharing is disabled.`n`n"
    } elseif ($groups[$anonymousSetting].Count -gt 0) {
        "External sharing is limited to security groups, but every group can share with Anyone. Anyone links need no sign-in, so you cannot tell who opened a shared file. In the SharePoint admin center, go to **Policies** > **Sharing** > **Manage security groups** and set **Can share with** to **Authenticated guests only** for at least one group.`n`n"
    } else {
        "External sharing in SharePoint Online is not limited to members of a security group. Add at least one security group that can share with authenticated guests only (WhoCanShareAuthenticatedGuestAllowList), or set SharingCapability to Disabled.`n`n"
    }
    $resultMarkdown += "| Setting | Value | Result |`n"
    $resultMarkdown += "| --- | --- | --- |`n"
    $rows = @("| SharingCapability | $displayCapability | $capabilityStatus |")
    foreach ($name in $groupSettings) {
        $displayGroups = if ($groups[$name].Count -eq 0) { 'Not set' } else { $groups[$name] -join ', ' }
        $rowStatus = if ($name -ne $requiredSetting) {
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
