function Test-MtCisaRequireActivationApproval {
    <#
    .SYNOPSIS
    Checks for approval requirement on activation of Global Admin role

    .DESCRIPTION
    Activation of the Global Administrator role SHALL require approval.

    .EXAMPLE
    Test-MtCisaRequireActivationApproval

    Returns true if the Global Administrator role requires approval on activation

    .LINK
    https://maester.dev/docs/commands/Test-MtCisaRequireActivationApproval
    #>
    [MaesterTest(
        Id = 'CISA.MS.AAD.7.6',
        Title = 'Activation of the Global Administrator role SHALL require approval.',
        Severity = 'High',
        Category = 'CISA',
        Tag = ('Entra ID P2', 'MS.AAD', 'MS.AAD.7.6'),
        Service = 'Graph',
        Author = 'soulemike',
        Contributor = ('ThorNicolai', 'JeanPhilippeGeorge')
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $EntraIDPlan = Get-MtLicenseInformation -Product EntraID
    $pim = $EntraIDPlan -eq "P2" -or $EntraIDPlan -eq "Governance"
    if (-not $pim) {
        Add-MtTestResultDetail -SkippedBecause NotLicensedEntraIDP2OrGovernance
        return $null
    }

    $globalAdministratorsRole = Get-MtRole | Where-Object {`
            $_.id -eq "62e90394-69f5-4237-9190-012177145e10" }

    $policySplat = @{
        ApiVersion      = "v1.0"
        RelativeUri     = "policies/roleManagementPolicyAssignments"
        Filter          = "scopeId eq '/' and scopeType eq 'DirectoryRole' and roleDefinitionId eq '$($globalAdministratorsRole.id)'"
        QueryParameters = @{
            expand = "policy(expand=rules)"
        }
    }
    $policy = Invoke-MtGraphRequest @policySplat

    $testResult = ($policy.policy.rules | Where-Object {`
                $_.'@odata.type' -eq "#microsoft.graph.unifiedRoleManagementPolicyApprovalRule"
        }).setting.isApprovalRequired -eq $true

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant requires approval for the activation of the Global Administrator role."
    } else {
        $testResultMarkdown = "Your tenant does not require approval for the activation of the Global Administrator role"
    }
    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
