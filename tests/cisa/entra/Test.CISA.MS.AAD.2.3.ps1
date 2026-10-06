function Test-MtCisaBlockHighRiskSignIn {
    <#
    .SYNOPSIS
    Checks if Sign-In Risk Based Policies - MS.AAD.2.3 is set to 'blocked'

    .DESCRIPTION
    Sign-ins detected as high risk SHALL be blocked.

    .EXAMPLE
    Test-MtCisaBlockHighRiskSignIn

    Returns true if at least one policy is set to block high risk sign-ins.

    .LINK
    https://maester.dev/docs/commands/Test-MtCisaBlockHighRiskSignIn
    #>
    [MaesterTest(
        Id = 'CISA.MS.AAD.2.3',
        Title = 'Sign-ins detected as high risk SHALL be blocked.',
        Severity = 'High',
        Category = 'CISA',
        Tag = ('Entra ID P2', 'MS.AAD', 'MS.AAD.2.3'),
        Service = 'Graph',
        CompatibleLicense = 'AAD_PREMIUM_P2',
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
        $_.conditions.signInRiskLevels -contains "high" -and `
        $_.conditions.users.includeUsers -contains "All" }

    $testResult = ($blockPolicies|Measure-Object).Count -ge 1

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant has one or more policies that block high risk sign-ins.`n`n"
    } else {
        $testResultMarkdown = "Your tenant does not have any Conditional Access policies that block high risk sign-ins.`n`n"
    }

    $checks = @{
        EnabledCount                            = ($result|Measure-Object).Count
        BlockCount                              = (($result|Where-Object {$_.grantControls.builtInControls -contains "block"})|Measure-Object).Count
        BlockAllAppsCount                       = (($result|Where-Object {$_.grantControls.builtInControls -contains "block" -and $_.conditions.applications.includeApplications -contains "all"})|Measure-Object).Count
        BlockAllAppsSignInRiskHighCount         = (($result|Where-Object {$_.grantControls.builtInControls -contains "block" -and $_.conditions.applications.includeApplications -contains "all" -and $_.conditions.signInRiskLevels -contains "high"})|Measure-Object).Count
        BlockAllAppsSignInRiskHighAllUsersCount = (($result|Where-Object {$_.grantControls.builtInControls -contains "block" -and $_.conditions.applications.includeApplications -contains "all" -and $_.conditions.signInRiskLevels -contains "high" -and $_.conditions.users.includeUsers -contains "All"})|Measure-Object).Count
    }

    $testResultMarkdown += "| Criteria | Count of Policies |`n"
    $testResultMarkdown += "| --- | --- |`n"
    $testResultMarkdown += "| Enabled | $($checks.EnabledCount) |`n"
    $testResultMarkdown += "| Enabled & Blocking | $($checks.BlockCount) |`n"
    $testResultMarkdown += "| Enabled, Blocking, & All Apps | $($checks.BlockAllAppsCount) |`n"
    $testResultMarkdown += "| Enabled, Blocking, All Apps, & Sign In Risk High | $($checks.BlockAllAppsSignInRiskHighCount) |`n"
    $testResultMarkdown += "| Enabled, Blocking, All Apps, Sign In Risk High, & All Users | $($checks.BlockAllAppsSignInRiskHighAllUsersCount) |`n`n"

    Add-MtTestResultDetail -Result $testResultMarkdown -GraphObjectType ConditionalAccess -GraphObjects $blockPolicies

    return $testResult
}
