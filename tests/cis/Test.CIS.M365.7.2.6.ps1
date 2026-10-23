function Test-MtCisSpoSharingDomainList {
    <#
    .SYNOPSIS
        Ensure SharePoint external sharing is managed through domain whitelist/blacklists

    .DESCRIPTION
        Checks that external sharing in SharePoint Online is limited by a domain allow list that names at least one domain, or that
        external sharing is turned off.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (7.2.6, L2)

    .EXAMPLE
        Test-MtCisSpoSharingDomainList

        Returns true if external sharing uses an allow list of domains or is disabled.

    .LINK
        https://maester.dev/docs/commands/Test-MtCisSpoSharingDomainList
    #>
    [MaesterTest(
        Id = 'CIS.M365.7.2.6',
        Title = 'Ensure SharePoint external sharing is managed through domain whitelist/blacklists',
        Product = 'sharepoint',
        Feature = 'external-sharing',
        Area = 'external-access',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Medium',
        ImplementationCost = 'Medium',
        Mitre = ('T1213.002', 'T1530', 'T1537'),
        Control = ('cis-m365:7.2.6', 'nist-800-53-r5:AC-21'),
        Service = 'SharePointOnline',
        Author = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Test-MtCisSpoSharingDomainList: Checking the sharing capability and domain restriction mode'
    $spoTenant = Get-MtSpo
    $sharingCapability = $spoTenant.SharingCapability
    $restrictionMode = $spoTenant.SharingDomainRestrictionMode
    $allowedDomains = @($spoTenant.SharingAllowedDomainList -split '\s+' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    $testResult = (($restrictionMode -eq 'AllowList') -and ($allowedDomains.Count -gt 0)) -or ($sharingCapability -eq 'Disabled')

    $displayCapability = if ($null -eq $sharingCapability) { 'Not found' } else { $sharingCapability }
    $displayMode = if ($null -eq $restrictionMode) { 'Not found' } else { $restrictionMode }
    $displayDomains = if ($allowedDomains.Count -gt 0) { $allowedDomains -join ', ' } else { 'None' }
    $resultMarkdown = if ($testResult) {
        "Well done. External sharing in SharePoint Online is limited to an allow list of domains or disabled.`n`n"
    } else {
        "External sharing in SharePoint Online is not limited to an allow list of domains, or the allow list is empty.`n`n"
    }
    $resultMarkdown += "| Setting | Value | Result |`n"
    $resultMarkdown += "| --- | --- | --- |`n"
    $resultMarkdown += "| SharingCapability | $displayCapability | $(if ($testResult) { 'Pass' } else { 'Fail' }) |`n"
    $domainStatus = if ($sharingCapability -eq 'Disabled') { 'Not applicable' } elseif ($testResult) { 'Pass' } else { 'Fail' }
    $resultMarkdown += "| SharingDomainRestrictionMode | $displayMode | $domainStatus |`n"
    $resultMarkdown += "| SharingAllowedDomainList | $displayDomains | $domainStatus |"

    Add-MtTestResultDetail -Result $resultMarkdown
    return $testResult
}
