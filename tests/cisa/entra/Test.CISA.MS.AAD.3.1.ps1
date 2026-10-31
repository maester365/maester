function Test-MtCisaPhishResistant {
    <#
    .SYNOPSIS
    Checks if a Conditional Access policy using Phishing-Resistant Authentication Strengths is enabled

    .DESCRIPTION
    Phishing-resistant MFA SHALL be enforced for all users
    This check does not assess exclusions, narrowing conditions or alternative grant controls on a matching policy.

    .EXAMPLE
    Test-MtCisaPhishResistant

    Returns true if at least one policy includes all users and all apps and specifies the built-in Phishing-resistant MFA
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

    # The built-in Phishing-resistant MFA strength, and the methods a custom strength may be limited to, as ScubaGear checks them.
    $phishingResistantStrengthId = '00000000-0000-0000-0000-000000000004'
    $phishingResistantMethods = @('windowsHelloForBusiness', 'fido2', 'x509CertificateMultiFactor')

    $result = Get-MtConditionalAccessPolicy | Where-Object { $_.state -eq "enabled" }

    $policies = $result | Where-Object {`
        $_.conditions.applications.includeApplications -contains "All" -and `
        $_.conditions.users.includeUsers -contains "All" -and `
        $_.grantControls.authenticationStrength -and (
            $_.grantControls.authenticationStrength.id -eq $phishingResistantStrengthId -or (
                @($_.grantControls.authenticationStrength.allowedCombinations).Count -gt 0 -and
                @($_.grantControls.authenticationStrength.allowedCombinations | Where-Object { $_ -notin $phishingResistantMethods }).Count -eq 0
            )
        ) }

    $testResult = ($policies|Measure-Object).Count -ge 1

    if ($testResult) {
        $testResultMarkdown = "Your tenant has one or more enabled policies that include all users and cloud apps and specify a phishing-resistant authentication strength. This check does not assess exclusions, narrowing conditions or alternative grant controls; review those separately.`n`n%TestResult%"
    } else {
        $testResultMarkdown = "Your tenant does not have any Conditional Access policies that require Phishing Resistant Authentication Strengths."
    }
    Add-MtTestResultDetail -Result $testResultMarkdown -GraphObjectType ConditionalAccess -GraphObjects $policies

    return $testResult
}
