function Test-MtCisaPhishResistant {
    <#
    .SYNOPSIS
    Checks if a Conditional Access policy using Phishing-Resistant Authentication Strengths is enabled

    .DESCRIPTION
    Phishing-resistant MFA SHALL be enforced for all users

    .EXAMPLE
    Test-MtCisaPhishResistant

    Returns true if at least one policy for all users and all apps requires the built-in Phishing-resistant MFA
    authentication strength, or a custom strength limited to Windows Hello for Business, passkeys (FIDO2) and
    certificate-based multifactor authentication

    .LINK
    https://maester.dev/docs/commands/Test-MtCisaPhishResistant
    #>
    [MaesterTest(
        Id = 'CISA.MS.AAD.3.1',
        Title = 'Phishing-resistant MFA SHALL be enforced for all users.',
        Product = 'entra',
        Feature = 'conditional-access',
        Area = 'authentication',
        ResourceType = 'Tenant',
        Severity = 'High',
        UserImpact = 'High',
        ImplementationCost = 'High',
        Mitre = 'T1566.002',
        Control = 'cisa-scuba:MS.AAD.3.1',
        Service = 'Graph',
        License = 'AAD_PREMIUM',
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $policies = Get-MtCisaPhishingResistantPolicy

    $testResult = ($policies|Measure-Object).Count -ge 1

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant has one or more policies that require Phishing Resistant Authentication Strengths :`n`n%TestResult%"
    } else {
        $testResultMarkdown = "Your tenant does not have any Conditional Access policies that require Phishing Resistant Authentication Strengths."
    }
    Add-MtTestResultDetail -Result $testResultMarkdown -GraphObjectType ConditionalAccess -GraphObjects $policies

    return $testResult
}
