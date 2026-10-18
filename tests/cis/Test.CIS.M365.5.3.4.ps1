function Test-MtCisGlobalAdminActivationApproval {
    <#
    .SYNOPSIS
        Checks that activating the Global Administrator role in PIM requires approval.

    .DESCRIPTION
        Checks the Privileged Identity Management settings of the Global Administrator role and passes when activation requires approval and at least one approver is defined.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (5.3.4, L1)

    .EXAMPLE
        Test-MtCisGlobalAdminActivationApproval

        Returns true if activating the Global Administrator role requires approval from at least one approver.

    .LINK
        https://maester.dev/docs/tests/CIS.M365.5.3.4
    #>
    [MaesterTest(
        Id = 'CIS.M365.5.3.4',
        Title = 'Ensure approval is required for Global Administrator role activation',
        Product = 'entra',
        Feature = 'privileged-identity-management',
        Area = 'privileged-access',
        ResourceType = 'DirectoryRole',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = ('T1078.004', 'T1548.005'),
        Control = ('cis-m365:5.3.4', 'nist-800-53-r5:AC-5'),
        Service = 'Graph',
        License = ('AAD_PREMIUM_P2', 'Entra_Identity_Governance'),
        Author = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Getting the Global Administrator role management policy...'
    $roleId = '62e90394-69f5-4237-9190-012177145e10'
    $assignment = Invoke-MtGraphRequest -RelativeUri 'policies/roleManagementPolicyAssignments' -Filter "scopeId eq '/' and scopeType eq 'Directory' and roleDefinitionId eq '$roleId'" -QueryParameters @{ expand = 'policy(expand=rules)' }
    $rule = @(@($assignment).policy.rules) | Where-Object { $_.id -eq 'Approval_EndUser_Assignment' } | Select-Object -First 1
    $isApprovalRequired = $rule.setting.isApprovalRequired
    $approvers = @($rule.setting.approvalStages.primaryApprovers | Where-Object { $_ } | ForEach-Object { if ($_.description) { $_.description } else { 'Unknown approver' } })
    $testResult = $isApprovalRequired -eq $true -and $approvers.Count -ge 1

    $passText = 'Activating the Global Administrator role requires approval.'
    $failText = if ($isApprovalRequired -eq $true) { 'Activating the Global Administrator role requires approval, but no approver is defined.' } else { 'Activating the Global Administrator role does not require approval.' }

    $resultMd = "| Setting | Value | Result |`n"
    $resultMd += "| --- | --- | --- |`n"
    $resultMd += "| Approval required | $(if ($null -eq $isApprovalRequired) { 'Not found' } else { $isApprovalRequired }) | $(if ($isApprovalRequired -eq $true) { '✅ Pass' } else { '❌ Fail' }) |`n"
    $resultMd += "| Approvers | $(if ($approvers.Count -gt 0) { $approvers -join ', ' } else { 'None' }) | $(if ($approvers.Count -ge 1) { '✅ Pass' } else { '❌ Fail' }) |`n"

    if ($testResult) {
        $testResultMarkdown = "Well done. $passText`n`n%TestResult%"
    } else {
        $testResultMarkdown = "$failText`n`n%TestResult%"
    }
    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $resultMd

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
