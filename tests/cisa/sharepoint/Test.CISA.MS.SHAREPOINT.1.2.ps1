function Test-MtCisaSpoOneDriveSharing {
    <#
    .SYNOPSIS
    Checks state of OneDrive sharing

    .DESCRIPTION
    External sharing for OneDrive SHALL be limited to Existing guests or Only People in your organization.

    .EXAMPLE
    Test-MtCisaSpoOneDriveSharing

    Returns true if OneDrive sharing is restricted

    .LINK
    https://maester.dev/docs/commands/Test-MtCisaSpoOneDriveSharing
    #>
    [MaesterTest(
        Id = 'CISA.MS.SHAREPOINT.1.2',
        Title = 'External sharing for OneDrive SHALL be limited to Existing guests or Only People in your organization.',
        Product = 'sharepoint',
        Feature = 'external-sharing',
        Area = 'external-access',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'High',
        ImplementationCost = 'Medium',
        Mitre = ('T1048', 'T1213.002', 'T1530'),
        Control = 'cisa-scuba:MS.SHAREPOINT.1.2',
        Service = 'SharePointOnline',
        Author = 'Mynster9361'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $spoTenant = Get-MtSpo

    # OneDriveSharingCapability: Disabled, ExistingExternalUserSharingOnly, ExternalUserSharingOnly, ExternalUserAndGuestSharing
    $testResult = $spoTenant.OneDriveSharingCapability -in @("Disabled", "ExistingExternalUserSharingOnly")

    if ($testResult) {
        $testResultMarkdown = "Well done. OneDrive sharing is restricted."
    } else {
        $testResultMarkdown = "OneDrive sharing is not restricted.`n`n* Current setting: ``$($spoTenant.OneDriveSharingCapability)``"
    }

    Add-MtTestResultDetail -Result $testResultMarkdown -Severity High

    return $testResult
}
