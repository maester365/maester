function Test-MtCisaMfa {
    <#
    .SYNOPSIS
    Checks if a Conditional Access policy requiring MFA is enabled

    .DESCRIPTION
    If phishing-resistant MFA has not been enforced, an alternative MFA method SHALL be enforced for all users

    .EXAMPLE
    Test-MtCisaMfa

    Returns true if at least one policy requires MFA

    .LINK
    https://maester.dev/docs/commands/Test-MtCisaMfa
    #>
    [MaesterTest(
        Id = 'CISA.MS.AAD.3.2',
        Title = 'If phishing-resistant MFA has not been enforced, an alternative MFA method SHALL be enforced for all users.',
        Severity = 'High',
        Category = 'CISA',
        Tag = ('Entra ID P1', 'MS.AAD', 'MS.AAD.3.2'),
        Service = 'Graph',
        CompatibleLicense = 'AAD_PREMIUM',
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if(Test-MtCisaPhishResistant){
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "Test-MtCisaPhishResistant Passed"
        return $null
    }

    $result = Get-MtConditionalAccessPolicy | Where-Object { $_.state -eq "enabled" }

    $policies = $result | Where-Object {`
        $_.conditions.applications.includeApplications -contains "All" -and `
        $_.conditions.users.includeUsers -contains "All" -and `
            ($_.grantControls.builtInControls -contains "mfa" -or `
            $_.grantControls.authenticationStrength.requirementsSatisfied -contains "mfa" ) }

    $testResult = ($policies|Measure-Object).Count -ge 1

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant has one or more policies that require MFA:`n`n%TestResult%"
    } else {
        $testResultMarkdown = "Your tenant does not have any Conditional Access policies that require MFA."
    }
    Add-MtTestResultDetail -Result $testResultMarkdown -GraphObjectType ConditionalAccess -GraphObjects $policies

    return $testResult
}
