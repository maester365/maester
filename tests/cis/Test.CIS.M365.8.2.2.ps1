function Test-MtCisCommunicateWithUnmanagedTeamsUsers {
    <#
    .SYNOPSIS
    Ensure communication with unmanaged Teams users is disabled

    .DESCRIPTION
    Communication with unmanaged Teams users is disabled
    CIS Microsoft 365 Foundations Benchmark v7.0.0 (8.2.2, L1)

    .EXAMPLE
    Test-MtCisCommunicateWithUnmanagedTeamsUsers

    Returns true if communication with unmanaged Teams users is disabled

    .LINK
    https://maester.dev/docs/commands/Test-MtCisCommunicateWithUnmanagedTeamsUsers
    #>
    [MaesterTest(
        Id = 'CIS.M365.8.2.2',
        Title = 'Ensure communication with unmanaged Teams users is disabled',
        Product = 'teams',
        Feature = 'external-access',
        Area = 'external-access',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Medium',
        ImplementationCost = 'Low',
        Mitre = ('T1566', 'T1204.001', 'T1204.002'),
        Control = ('cis-m365:8.2.2', 'nist-800-53-r5:AC-20'),
        Service = 'Teams',
        Author = 'HenrikPiecha',
        Contributor = ('merill', 'Mynster9361')
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'This test checks multiple users.')]
    param()

    Write-Verbose 'Test-MtCisCommunicateWithUnmanagedTeamsUsers: Checking if communication with unmanaged Teams users is disabled'

    $federation = Get-CsTenantFederationConfiguration
    $externalAccessPolicy = Get-CsExternalAccessPolicy -Identity Global
    $orgSetting = $federation.AllowTeamsConsumer
    $policySetting = $externalAccessPolicy.EnableTeamsConsumerAccess
    $testResult = $orgSetting -eq $false -or $policySetting -eq $false

    $resultMarkdown = if ($testResult) {
        "Well done. Communication with unmanaged Teams users is disabled.`n`n"
    } else {
        "Communication with unmanaged Teams users is enabled. Turn it off in the Global external access policy or in the organization settings.`n`n"
    }
    $resultMarkdown += "| Setting | Value | Result |`n"
    $resultMarkdown += "| --- | --- | --- |`n"
    $resultMarkdown += "| AllowTeamsConsumer (organization settings) | $(if ($null -eq $orgSetting) { 'Not found' } else { $orgSetting }) | $(if ($orgSetting -eq $false) { 'Pass' } else { 'Fail' }) |`n"
    $resultMarkdown += "| EnableTeamsConsumerAccess (Global external access policy) | $(if ($null -eq $policySetting) { 'Not found' } else { $policySetting }) | $(if ($policySetting -eq $false) { 'Pass' } else { 'Fail' }) |`n"
    $resultMarkdown += "`nEither setting turned off meets the CIS recommendation."

    Add-MtTestResultDetail -Result $resultMarkdown
    return $testResult
}
