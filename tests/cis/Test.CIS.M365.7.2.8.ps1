function Test-MtCisSpoSharingSecurityGroup {
    <#
    .SYNOPSIS
        Ensure external sharing is restricted by security group

    .DESCRIPTION
        Checks that only members of a security group can share SharePoint and OneDrive content with authenticated guests, or that external sharing is disabled. The test passes when SharingCapability is Disabled or WhoCanShareAuthenticatedGuestAllowList contains at least one group. A group in WhoCanShareAnonymousAllowList alone does not satisfy this control because that list permits anonymous sharing. The legacy guest sharing group list is reported for information only.

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
    # The authenticated-guest list restricts sharing to its groups. The anonymous list permits Anyone links and is informational for this control.
    # The older guest sharing group list is read for information only. An empty value counts as not set.
    $authenticatedGuestAllowList = 'WhoCanShareAuthenticatedGuestAllowList'
    $groupSettings = @(
        $authenticatedGuestAllowList
        'WhoCanShareAnonymousAllowList'
        'GuestSharingGroupAllowListInTenantByPrincipalIdentity'
    )
    $groups = [ordered]@{}
    foreach ($name in $groupSettings) {
        $value = if ($spoTenant.PSObject.Properties[$name]) { $spoTenant.$name } else { $null }
        $groups[$name] = @($value | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
    }
    $hasAuthenticatedGuestAllowListGroup = $groups[$authenticatedGuestAllowList].Count -gt 0
    $isDisabled = $sharingCapability -eq 'Disabled'
    $testResult = $isDisabled -or $hasAuthenticatedGuestAllowListGroup

    $displayCapability = if ($null -eq $sharingCapability) { 'Not found' } else { $sharingCapability }
    $capabilityStatus = if ($isDisabled) { 'Pass' } else { 'Info' }
    $resultMarkdown = if ($testResult) {
        "Well done. Only members of a security group can share externally, or external sharing is disabled.`n`n"
    }
    else {
        "External sharing in SharePoint Online is not restricted to members of a security group in WhoCanShareAuthenticatedGuestAllowList. Set at least one group there, or set SharingCapability to Disabled.`n`n"
    }
    $resultMarkdown += "| Setting | Value | Result |`n"
    $resultMarkdown += "| --- | --- | --- |`n"
    $rows = @("| SharingCapability | $displayCapability | $capabilityStatus |")
    foreach ($name in $groupSettings) {
        $displayGroups = if ($groups[$name].Count -eq 0) { 'Not set' } else { $groups[$name] -join ', ' }
        $rowStatus = if ($name -ne $authenticatedGuestAllowList) {
            'Info'
        }
        elseif ($groups[$name].Count -gt 0) {
            'Pass'
        }
        elseif ($testResult) {
            'Not required'
        }
        else {
            'Fail'
        }
        $rows += "| $name | $displayGroups | $rowStatus |"
    }
    $resultMarkdown += $rows -join "`n"

    Add-MtTestResultDetail -Result $resultMarkdown
    return $testResult
}
