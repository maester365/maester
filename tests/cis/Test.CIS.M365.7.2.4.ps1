function Test-MtCisOneDriveContentSharing {
    <#
    .SYNOPSIS
        Ensure OneDrive content sharing is restricted

    .DESCRIPTION
        Checks that sharing from the OneDrive site of the tenant is turned off, so that content is
        shared only within the organization.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (7.2.4, L2)

    .EXAMPLE
        Test-MtCisOneDriveContentSharing

        Returns true if sharing from OneDrive is disabled.

    .LINK
        https://maester.dev/docs/commands/Test-MtCisOneDriveContentSharing
    #>
    [MaesterTest(
        Id = 'CIS.M365.7.2.4',
        Title = 'Ensure OneDrive content sharing is restricted',
        Product = 'sharepoint',
        Feature = 'external-sharing',
        Area = 'external-access',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Medium',
        ImplementationCost = 'Low',
        Mitre = ('T1213.002', 'T1530'),
        Control = ('cis-m365:7.2.4', 'nist-800-53-r5:AC-21'),
        Service = 'SharePointOnline',
        Author = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Test-MtCisOneDriveContentSharing: Checking the OneDrive sharing capability of the tenant'
    $spoTenant = Get-MtSpo
    $setting = $spoTenant.OneDriveSharingCapability
    $testResult = $setting -eq 'Disabled'

    $displayValue = if ($null -eq $setting) { 'Not found' } else { $setting }
    $resultMarkdown = if ($testResult) {
        "Well done. Content sharing from OneDrive is disabled.`n`n"
    } else {
        "Content sharing from OneDrive is enabled.`n`n"
    }
    $resultMarkdown += "| Setting | Value | Result |`n"
    $resultMarkdown += "| --- | --- | --- |`n"
    $resultMarkdown += "| OneDriveSharingCapability | $displayValue | $(if ($testResult) { 'Pass' } else { 'Fail' }) |"

    Add-MtTestResultDetail -Result $resultMarkdown
    return $testResult
}
