function Test-MtCisSpoModernAuthentication {
    <#
    .SYNOPSIS
        Ensure modern authentication for SharePoint applications is required

    .DESCRIPTION
        Checks that legacy authentication protocols are disabled for SharePoint Online.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (7.2.1, L1)

    .EXAMPLE
        Test-MtCisSpoModernAuthentication

        Returns true if legacy authentication protocols are disabled for SharePoint Online.

    .LINK
        https://maester.dev/docs/commands/Test-MtCisSpoModernAuthentication
    #>
    [MaesterTest(
        Id = 'CIS.M365.7.2.1',
        Title = 'Ensure modern authentication for SharePoint applications is required',
        Product = 'sharepoint',
        Feature = 'access-control',
        Area = 'authentication',
        ResourceType = 'Tenant',
        Severity = 'High',
        UserImpact = 'Medium',
        ImplementationCost = 'Low',
        Mitre = 'T1110',
        Control = ('cis-m365:7.2.1', 'nist-800-53-r5:IA-2'),
        Service = 'SharePointOnline',
        Author = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Test-MtCisSpoModernAuthentication: Checking the legacy authentication protocol setting'
    $spoTenant = Get-MtSpo
    $setting = $spoTenant.LegacyAuthProtocolsEnabled
    $testResult = $setting -eq $false

    $displayValue = if ($null -eq $setting) { 'Not found' } else { $setting }
    $resultMarkdown = if ($testResult) {
        "Well done. Legacy authentication protocols are disabled for SharePoint Online.`n`n"
    } else {
        "Legacy authentication protocols are enabled for SharePoint Online.`n`n"
    }
    $resultMarkdown += "| Setting | Value | Result |`n"
    $resultMarkdown += "| --- | --- | --- |`n"
    $resultMarkdown += "| LegacyAuthProtocolsEnabled | $displayValue | $(if ($testResult) { 'Pass' } else { 'Fail' }) |"

    Add-MtTestResultDetail -Result $resultMarkdown
    return $testResult
}
