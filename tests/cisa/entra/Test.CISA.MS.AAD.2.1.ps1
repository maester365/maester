function Test-MtCisaBlockHighRiskUser {
    <#
    .SYNOPSIS
    Checks if User Risk Based Policies - MS.AAD.2.1 is set to 'blocked'

    .DESCRIPTION
    Users detected as high risk SHALL be blocked.

    .EXAMPLE
    Test-MtCisaBlockHighRiskUser

    Returns true if at least one policy is set to block high risk users.

    .LINK
    https://maester.dev/docs/commands/Test-MtCisaBlockHighRiskUser
    #>
    [MaesterTest(
        Id = 'CISA.MS.AAD.2.1',
        Title = 'Users detected as high risk SHALL be blocked.',
        Severity = 'High',
        Category = 'CISA',
        Product = 'Entra ID',
        Tag = ('Entra ID P2', 'MS.AAD', 'MS.AAD.2.1'),
        Service = 'Graph',
        License = 'AAD_PREMIUM_P2',
        Author = 'soulemike',
        Contributor = 'merill'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $result = Get-MtConditionalAccessPolicy | Where-Object { $_.state -eq "enabled" }

    $blockPolicies = $result | Where-Object {`
        $_.grantControls.builtInControls -contains "block" -and `
        $_.conditions.applications.includeApplications -contains "all" -and `
        $_.conditions.userRiskLevels -contains "high" -and `
        $_.conditions.users.includeUsers -contains "All" }

    $testResult = ($blockPolicies|Measure-Object).Count -ge 1

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant has one or more policies that block high risk users :`n`n%TestResult%"
    } else {
        $testResultMarkdown = "Your tenant does not have any Conditional Access policies that block high risk users."
    }
    Add-MtTestResultDetail -Result $testResultMarkdown -GraphObjectType ConditionalAccess -GraphObjects $blockPolicies

    return $testResult
}
