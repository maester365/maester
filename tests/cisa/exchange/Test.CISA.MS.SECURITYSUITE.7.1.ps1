function Test-MtCisaSafeLink {
    <#
    .SYNOPSIS
    Checks URL protection for the effective all-recipient Safe Links policy.

    .DESCRIPTION
    URL comparison with a block-list SHOULD be enabled for URLs in emails, Teams messages, and Office documents.

    .EXAMPLE
    Test-MtCisaSafeLink

    Returns true when the active preset or highest-priority all-recipient Safe Links policy enables protection for email, Teams, Office documents, and internal senders.

    .LINK
    https://maester.dev/docs/commands/Test-MtCisaSafeLink
    #>
    [MaesterTest(
        Id = 'CISA.MS.SECURITYSUITE.7.1',
        Title = 'URL comparison with a block-list SHOULD be enabled for URLs in emails, Teams messages, and Office documents.',
        Product = 'exchange',
        RelatedProduct = 'defender',
        Feature = 'safe-links',
        Area = 'email-protection',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = ('T1566.002', 'T1204.001'),
        Control = 'cisa-scuba:MS.SECURITYSUITE.7.1',
        Service = ('ExchangeOnline', 'Graph'),
        License = 'ATP_ENTERPRISE',
        Author = 'soulemike',
        Contributor = ('thomas-s-schmidt', 'JeremyFinney-lgtm')
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $effectivePolicy = Get-MtCisaEffectiveSafeLinksPolicy
    $selectedPolicy = $effectivePolicy.Policy

    $testResult = $null -ne $selectedPolicy -and
        $selectedPolicy.EnableSafeLinksForEmail -eq $true -and
        $selectedPolicy.EnableSafeLinksForTeams -eq $true -and
        $selectedPolicy.EnableSafeLinksForOffice -eq $true -and
        $selectedPolicy.EnableForInternalSenders -eq $true

    $status = if ($testResult) { '✅ Pass' } else { '❌ Fail' }
    $email = if ($selectedPolicy.EnableSafeLinksForEmail -eq $true) { 'Enabled' } else { 'Disabled' }
    $teams = if ($selectedPolicy.EnableSafeLinksForTeams -eq $true) { 'Enabled' } else { 'Disabled' }
    $office = if ($selectedPolicy.EnableSafeLinksForOffice -eq $true) { 'Enabled' } else { 'Disabled' }
    $internal = if ($selectedPolicy.EnableForInternalSenders -eq $true) { 'Enabled' } else { 'Disabled' }
    $result = "| Effective policy | Selection | Email | Teams | Office documents | Internal senders | Result |`n"
    $result += "| --- | --- | --- | --- | --- | --- | --- |`n"
    $result += "| $($effectivePolicy.PolicyName) | $($effectivePolicy.SelectionReason) | $email | $teams | $office | $internal | $status |`n"

    if ($testResult) {
        $message = "Well done. The effective all-recipient Safe Links policy enables URL protection for email, Teams, Office documents, and internal senders.`n`n%TestResult%"
    } else {
        $message = "Enable Safe Links and internal-sender protection on the effective all-recipient policy. A preset policy applies only when its all-recipient preset rule is enabled; otherwise the highest-priority all-recipient custom rule applies.`n`n%TestResult%"
    }

    Add-MtTestResultDetail -Result ($message -replace '%TestResult%', $result)
    return [bool]$testResult
}
