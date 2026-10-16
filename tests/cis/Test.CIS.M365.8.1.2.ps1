function Test-MtCisTeamsEmailToChannelDisabled {
    <#
    .SYNOPSIS
        Ensure users can't send emails to a channel email address

    .DESCRIPTION
        Checks that the Global Teams client configuration does not allow users to send email to a channel
        email address.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (8.1.2, L1)

    .EXAMPLE
        Test-MtCisTeamsEmailToChannelDisabled

        Returns true if users cannot send emails to a channel email address.

    .LINK
        https://maester.dev/docs/commands/Test-MtCisTeamsEmailToChannelDisabled
    #>
    [MaesterTest(
        Id = 'CIS.M365.8.1.2',
        Title = 'Ensure users can''t send emails to a channel email address',
        Product = 'teams',
        Feature = 'messaging',
        Area = 'external-access',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = 'T1566',
        Control = ('cis-m365:8.1.2', 'nist-800-53-r5:AC-20'),
        Service = 'Teams',
        Author = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Test-MtCisTeamsEmailToChannelDisabled: Checking the Global Teams client configuration'
    $clientConfig = Get-CsTeamsClientConfiguration -Identity Global
    $setting = $clientConfig.AllowEmailIntoChannel
    $testResult = $setting -eq $false

    $displayValue = if ($null -eq $setting) { 'Not found' } else { $setting }
    $resultMarkdown = if ($testResult) {
        "Well done. Users cannot send emails to a channel email address.`n`n"
    } else {
        "Users can send emails to a channel email address.`n`n"
    }
    $resultMarkdown += "| Setting | Value | Result |`n"
    $resultMarkdown += "| --- | --- | --- |`n"
    $resultMarkdown += "| AllowEmailIntoChannel | $displayValue | $(if ($testResult) { 'Pass' } else { 'Fail' }) |"

    Add-MtTestResultDetail -Result $resultMarkdown
    return $testResult
}
