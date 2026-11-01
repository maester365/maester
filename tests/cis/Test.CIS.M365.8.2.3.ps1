function Test-MtCisCommunicateInitiateExternalTeamsUsers {
    <#
    .SYNOPSIS
    Ensure external Teams users cannot initiate conversations

    .DESCRIPTION
    External Teams users cannot initiate conversations
    CIS Microsoft 365 Foundations Benchmark v7.0.0 (8.2.3)

    .EXAMPLE
    Test-MtCisCommunicateInitiateExternalTeamsUsers

    Returns true if external Teams users cannot initiate conversations

    .LINK
    https://maester.dev/docs/commands/Test-MtCisCommunicateInitiateExternalTeamsUsers
    #>
    [MaesterTest(
        Id = 'CIS.M365.8.2.3',
        Title = 'Ensure external Teams users cannot initiate conversations',
        Product = 'teams',
        Feature = 'external-access',
        Area = 'external-access',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = ('T1566', 'T1204.001', 'T1204.002'),
        Control = ('cis-m365:8.2.3', 'nist-800-53-r5:AC-20'),
        Service = 'Teams',
        Author = 'Mynster9361',
        Contributor = 'merill'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'This test checks multiple users.')]
    param()

    Write-Verbose 'Test-MtCisCommunicateInitiateExternalTeamsUsers: Checking if external unmanaged Teams users cannot initiate conversations'

    $federation = Get-CsTenantFederationConfiguration
    $externalAccessPolicy = Get-CsExternalAccessPolicy -Identity Global
    $orgSetting = $federation.AllowTeamsConsumerInbound
    $policySetting = $externalAccessPolicy.EnableTeamsConsumerInbound
    $testResult = $orgSetting -eq $false -or $policySetting -eq $false

    $resultMarkdown = if ($testResult) {
        "Well done. External unmanaged Teams users cannot initiate conversations.`n`n"
    } else {
        "External unmanaged Teams users can initiate conversations. Turn this off in the Global external access policy or in the organization settings.`n`n"
    }
    $resultMarkdown += "| Setting | Value | Result |`n"
    $resultMarkdown += "| --- | --- | --- |`n"
    $resultMarkdown += "| AllowTeamsConsumerInbound (organization settings) | $(if ($null -eq $orgSetting) { 'Not found' } else { $orgSetting }) | $(if ($orgSetting -eq $false) { 'Pass' } else { 'Fail' }) |`n"
    $resultMarkdown += "| EnableTeamsConsumerInbound (Global external access policy) | $(if ($null -eq $policySetting) { 'Not found' } else { $policySetting }) | $(if ($policySetting -eq $false) { 'Pass' } else { 'Fail' }) |`n"
    $resultMarkdown += "`nEither setting turned off meets the CIS recommendation."

    Add-MtTestResultDetail -Result $resultMarkdown
    return $testResult
}
