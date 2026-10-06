function Test-MtCisaPrivilegedPhishResistant {
    <#
    .SYNOPSIS
    Checks if a Conditional Access policy requiring phishing resistant authentication methods for privileged roles is enabled

    .DESCRIPTION
    Phishing-resistant MFA SHALL be required for highly privileged roles.

    .EXAMPLE
    Test-MtCisaPrivilegedPhishResistant

    Returns true if at least one policy requires phishing resistant methods for the specific roles

    .LINK
    https://maester.dev/docs/commands/Test-MtCisaPrivilegedPhishResistant
    #>
    [MaesterTest(
        Id = 'CISA.MS.AAD.3.6',
        Title = 'Phishing-resistant MFA SHALL be required for highly privileged roles.',
        Severity = 'High',
        Category = 'CISA',
        Tag = ('Entra ID P1', 'MS.AAD', 'MS.AAD.3.6'),
        Service = 'Graph',
        CompatibleLicense = 'AAD_PREMIUM',
        Author = 'soulemike',
        Contributor = 'michaelmsonne'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $highlyPrivilegedRoles = Get-MtRole -CisaHighlyPrivilegedRoles

    $result = Get-MtConditionalAccessPolicy | Where-Object { $_.state -eq "enabled" }

    #Hacky approach to do validation of all objects
    $policies = $result | Where-Object {`
        $_.conditions.applications.includeApplications -contains "All" -and `
        $_.grantControls.authenticationStrength.displayName -eq "Phishing-resistant MFA" -and `
        ($_.conditions.users.includeRoles|Sort-Object) -join "," -like "*$(($highlyPrivilegedRoles.id|Sort-Object) -join "*")*" }

    $testResult = ($policies|Measure-Object).Count -ge 1

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant has one or more policies that require phishing resistant MFA for highly privileged users:`n`n%TestResult%"
    } else {
        $testResultMarkdown = "Your tenant does not have any Conditional Access policies that require phishing resistant MFA for highly privileged users."
    }
    Add-MtTestResultDetail -Result $testResultMarkdown -GraphObjectType ConditionalAccess -GraphObjects $policies

    return $testResult
}
