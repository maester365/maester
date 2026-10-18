function Test-MtCisPrivilegedRoleAdminActivationApproval {
    <#
    .SYNOPSIS
        Checks that activating the Privileged Role Administrator role in PIM requires approval.

    .DESCRIPTION
        Checks the Privileged Identity Management settings of the Privileged Role Administrator role and passes when activation requires approval and at least one approver is defined.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (5.3.5, L1)

    .EXAMPLE
        Test-MtCisPrivilegedRoleAdminActivationApproval

        Returns true if activating the Privileged Role Administrator role requires approval from at least one approver.

    .LINK
        https://maester.dev/docs/tests/CIS.M365.5.3.5
    #>
    [MaesterTest(
        Id = 'CIS.M365.5.3.5',
        Title = 'Ensure approval is required for Privileged Role Administrator activation',
        Product = 'entra',
        Feature = 'privileged-identity-management',
        Area = 'privileged-access',
        ResourceType = 'DirectoryRole',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = ('T1078.004', 'T1098.003'),
        Control = ('cis-m365:5.3.5', 'nist-800-53-r5:AC-5'),
        Service = 'Graph',
        License = ('AAD_PREMIUM_P2', 'Entra_Identity_Governance'),
        Author = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Getting the Privileged Role Administrator role management policy...'
    $roleId = 'e8611ab8-c189-46e8-94e1-60213ab1f814'
    $assignment = Invoke-MtGraphRequest -RelativeUri 'policies/roleManagementPolicyAssignments' -Filter "scopeId eq '/' and scopeType eq 'DirectoryRole' and roleDefinitionId eq '$roleId'" -QueryParameters @{ expand = 'policy(expand=rules)' }
    $rule = @(@($assignment).policy.rules) | Where-Object { $_.id -eq 'Approval_EndUser_Assignment' } | Select-Object -First 1
    $isApprovalRequired = $rule.setting.isApprovalRequired
    $approvers = @($rule.setting.approvalStages.primaryApprovers | Where-Object { $_ } | ForEach-Object { if ($_.description) { $_.description } else { 'Unknown approver' } })
    $testResult = $isApprovalRequired -eq $true -and $approvers.Count -ge 1

    $passText = 'Activating the Privileged Role Administrator role requires approval.'
    $failText = if ($isApprovalRequired -eq $true) { 'Activating the Privileged Role Administrator role requires approval, but no approver is defined.' } else { 'Activating the Privileged Role Administrator role does not require approval.' }

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
