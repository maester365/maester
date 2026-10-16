function Test-MtCisSpoSharingSecurityGroup {
    <#
    .SYNOPSIS
        Ensure external sharing is restricted by security group

    .DESCRIPTION
        Checks that external sharing in SharePoint Online is limited to members of a security group, or
        that external sharing is turned off.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (7.2.8, L2)

    .EXAMPLE
        Test-MtCisSpoSharingSecurityGroup

        Returns true if external sharing is limited to a security group or disabled.

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

    Write-Verbose 'Test-MtCisSpoSharingSecurityGroup: Checking the sharing capability and the security group allow list'
    $spoTenant = Get-MtSpo
    $sharingCapability = $spoTenant.SharingCapability
    $securityGroup = $spoTenant.GuestSharingGroupAllowListInTenantByPrincipalIdentity
    # An empty group name counts as not set.
    $hasSecurityGroup = -not [string]::IsNullOrWhiteSpace([string]$securityGroup)
    $testResult = $hasSecurityGroup -or ($sharingCapability -eq 'Disabled')

    $displayCapability = if ($null -eq $sharingCapability) { 'Not found' } else { $sharingCapability }
    $displayGroup = if (-not $hasSecurityGroup) { 'Not set' } else { $securityGroup }
    $resultMarkdown = if ($testResult) {
        "Well done. External sharing in SharePoint Online is limited to a security group or disabled.`n`n"
    } else {
        "External sharing in SharePoint Online is not limited to a security group.`n`n"
    }
    $resultMarkdown += "| Setting | Value | Result |`n"
    $resultMarkdown += "| --- | --- | --- |`n"
    $resultMarkdown += "| SharingCapability | $displayCapability | $(if ($testResult) { 'Pass' } else { 'Fail' }) |`n"
    $resultMarkdown += "| GuestSharingGroupAllowListInTenantByPrincipalIdentity | $displayGroup | $(if ($testResult) { 'Pass' } else { 'Fail' }) |"

    Add-MtTestResultDetail -Result $resultMarkdown
    return $testResult
}
