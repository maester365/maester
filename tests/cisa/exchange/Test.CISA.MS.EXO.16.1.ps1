function Test-MtCisaExoAlert {
    <#
    .SYNOPSIS
    Checks state of alerts

    .DESCRIPTION
    Alerts SHALL be enabled.

    .EXAMPLE
    Test-MtCisaExoAlert

    Returns true if alerts enabled

    .LINK
    https://maester.dev/docs/commands/Test-MtCisaExoAlert
    #>
    [MaesterTest(
        Id = 'CISA.MS.EXO.16.1',
        Title = 'Alerts SHALL be enabled.',
        Product = 'exchange',
        RelatedProduct = 'defender',
        Feature = 'alerts',
        Area = 'logging-and-detection',
        ResourceType = 'Policy',
        Severity = 'High',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = ('T1114.003', 'T1204.001'),
        Control = 'cisa-scuba:MS.EXO.16.1',
        Service = ('ExchangeOnline', 'Graph', 'SecurityCompliance'),
        License = 'ATP_ENTERPRISE',
        Author = 'soulemike',
        Contributor = 'thomas-s-schmidt'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $alerts = Get-MtExo -Request ProtectionAlert

    # Matched by name and Disabled, as ScubaGear does: object IDs differ per tenant, and
    # NotificationEnabled only says whether an email is sent.
    $cisaAlerts = @(
        'Suspicious email sending patterns detected'
        'Suspicious connector activity'
        'Suspicious Email Forwarding Activity'
        'Messages have been delayed'
        'Tenant restricted from sending unprovisioned email'
        'Tenant restricted from sending email'
    )
    if ("P2" -in (Get-MtLicenseInformation -Product MdoV2)) {
        $cisaAlerts += 'A potentially malicious URL click was detected'
    }

    $resultAlerts = $alerts | Where-Object { $_.Name -in $cisaAlerts -and $_.Disabled -eq $false }

    $testResult = @($cisaAlerts | Where-Object { $_ -notin $resultAlerts.Name }).Count -eq 0

    $portalLink = 'https://security.microsoft.com/alertpoliciesv2'
    $passResult = '✅ Pass'
    $failResult = '❌ Fail'

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant has [alerts configured]($portalLink).`n`n%TestResult%"
    } else {
        $testResultMarkdown = "Your tenant does not have all [alerts configured]($portalLink).`n`n%TestResult%"
    }

    $result = "| Alert Name | Alert Result |`n"
    $result += "| --- | --- |`n"
    foreach ($item in $cisaAlerts) {
        if ($item -in $resultAlerts.Name) {
            $result += "| $item | $passResult |`n"
        } else {
            $result += "| $item | $failResult |`n"
        }
    }

    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
