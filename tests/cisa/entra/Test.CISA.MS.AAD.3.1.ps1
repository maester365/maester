function Test-MtCisaPhishResistant {
    <#
    .SYNOPSIS
    Checks if a Conditional Access policy using Phishing-Resistant Authentication Strengths is enabled

    .DESCRIPTION
    Phishing-resistant MFA SHALL be enforced for all users

    .EXAMPLE
    Test-MtCisaPhishResistant

    Returns true if at least one policy is set to use the built-in phishing resistant authentication strengths

    .LINK
    https://maester.dev/docs/commands/Test-MtCisaPhishResistant
    #>
    [MaesterTest(
        Id = 'CISA.MS.AAD.3.1',
        Title = 'Phishing-resistant MFA SHALL be enforced for all users.',
        Severity = 'High',
        Category = 'CISA',
        Tag = ('Entra ID P1', 'MS.AAD', 'MS.AAD.3.1'),
        Service = 'Graph',
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $EntraIDPlan = Get-MtLicenseInformation -Product EntraID
    if($EntraIDPlan -eq "Free"){
        Add-MtTestResultDetail -SkippedBecause NotLicensedEntraIDP1
        return $null
    }

    $result = Get-MtConditionalAccessPolicy | Where-Object { $_.state -eq "enabled" }

    $policies = $result | Where-Object {`
        $_.conditions.applications.includeApplications -contains "All" -and `
        $_.conditions.users.includeUsers -contains "All" -and `
        $_.grantControls.authenticationStrength.displayName -eq "Phishing-resistant MFA" }

    $testResult = ($policies|Measure-Object).Count -ge 1

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant has one or more policies that require Phishing Resistant Authentication Strengths :`n`n%TestResult%"
    } else {
        $testResultMarkdown = "Your tenant does not have any Conditional Access policies that require Phishing Resistant Authentication Strengths."
    }
    Add-MtTestResultDetail -Result $testResultMarkdown -GraphObjectType ConditionalAccess -GraphObjects $policies

    return $testResult
}
