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
        Id = 'CISA.MS.SECURITYSUITE.4.1',
        Title = 'At a minimum, the following alerts SHALL be enabled.',
        Product = 'exchange',
        RelatedProduct = 'defender',
        Feature = 'alerts',
        Area = 'logging-and-detection',
        ResourceType = 'Policy',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = ('T1114.003', 'T1204.001'),
        Control = 'cisa-scuba:MS.SECURITYSUITE.4.1',
        Service = 'ExchangeOnline',
        License = 'ATP_ENTERPRISE',
        Author = 'soulemike',
        Contributor = ('thomas-s-schmidt', 'JeremyFinney-lgtm')
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $alerts = Get-MtExo -Request ProtectionAlert

    $requiredAlerts = @(
        'Suspicious email sending patterns detected',
        'Suspicious connector activity',
        'Suspicious Email Forwarding Activity',
        'Messages have been delayed',
        'Tenant restricted from sending unprovisioned email',
        'Tenant restricted from sending email'
    )
    if (@($alerts | Where-Object { $_.Name -eq 'A potentially malicious URL click was detected' }).Count -gt 0) {
        $requiredAlerts += 'A potentially malicious URL click was detected'
    }

    $missingAlerts = @(
        $requiredAlerts | Where-Object {
            $alertName = $_
            @($alerts | Where-Object { $_.Name -eq $alertName -and $_.Disabled -eq $false }).Count -eq 0
        }
    )
    $testResult = $missingAlerts.Count -eq 0

    $portalLink = 'https://security.microsoft.com/alertpoliciesv2'

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant has [alerts configured]($portalLink).`n`n%TestResult%"
    } else {
        $testResultMarkdown = "Your tenant does not have all [alerts configured]($portalLink).`n`n%TestResult%"
    }

    $result = foreach ($alertName in $requiredAlerts) {
        if ($alertName -notin $missingAlerts) {
            "- **${alertName}:** enabled."
        } else {
            "- **${alertName}:** missing or disabled."
        }
    }

    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', ($result -join "`n")

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
