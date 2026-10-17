function Test-MtCisSpoExternalContentSharing {
    <#
    .SYNOPSIS
        Ensure external content sharing is restricted

    .DESCRIPTION
        Checks that SharePoint Online external sharing is limited to guests that already exist in the
        tenant, or is turned off.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (7.2.3, L1)

    .EXAMPLE
        Test-MtCisSpoExternalContentSharing

        Returns true if external content sharing is restricted to existing guests or disabled.

    .LINK
        https://maester.dev/docs/commands/Test-MtCisSpoExternalContentSharing
    #>
    [MaesterTest(
        Id = 'CIS.M365.7.2.3',
        Title = 'Ensure external content sharing is restricted',
        Product = 'sharepoint',
        Feature = 'external-sharing',
        Area = 'external-access',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Medium',
        ImplementationCost = 'Low',
        Mitre = ('T1213.002', 'T1530'),
        Control = ('cis-m365:7.2.3', 'nist-800-53-r5:AC-21'),
        Service = 'SharePointOnline',
        Author = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Test-MtCisSpoExternalContentSharing: Checking the tenant sharing capability'
    $spoTenant = Get-MtSpo
    $setting = $spoTenant.SharingCapability
    $testResult = $setting -in @('ExternalUserSharingOnly', 'ExistingExternalUserSharingOnly', 'Disabled')

    $displayValue = if ($null -eq $setting) { 'Not found' } else { $setting }
    $resultMarkdown = if ($testResult) {
        "Well done. External sharing in SharePoint Online is restricted to existing guests or disabled.`n`n"
    } else {
        "External sharing in SharePoint Online allows anyone to receive content, which is not restricted.`n`n"
    }
    $resultMarkdown += "| Setting | Value | Result |`n"
    $resultMarkdown += "| --- | --- | --- |`n"
    $resultMarkdown += "| SharingCapability | $displayValue | $(if ($testResult) { 'Pass' } else { 'Fail' }) |"

    Add-MtTestResultDetail -Result $resultMarkdown
    return $testResult
}
