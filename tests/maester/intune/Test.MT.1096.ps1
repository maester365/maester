function Test-MtOperationApprovalPolicies {
    <#
    .SYNOPSIS
    Check for the usage of Intune Multi Admin Approval Policies

    .DESCRIPTION
    At least one Intune Multi Admin Approval Policy should be configured.

    With RequiredPolicyType the check passes only when a policy of one of those types exists, for example
    deviceWipe or deviceAction for a policy that protects device wipes.

    .EXAMPLE
    Test-MtOperationApprovalPolicies

    Returns true if at least one Intune Multi Admin Approval Policy is configured, false if none is configured.

    .EXAMPLE
    Test-MtOperationApprovalPolicies -RequiredPolicyType deviceWipe, deviceAction

    Returns true if a Multi Admin Approval policy protects device wipes.

    .LINK
    https://maester.dev/docs/commands/Test-MtOperationApprovalPolicies
    #>
    [MaesterTest(
        Id = 'MT.1096',
        Title = 'Ensure at least one Intune Multi Admin Approval policy is configured',
        Product = 'intune',
        Feature = 'tenant-administration',
        Area = 'privileged-access',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = ('T1072', 'T1078.004'),
        Control = ('nist-800-53-r5:AC-3(2)', 'nist-800-53-r5:CM-5(4)'),
        Service = 'Graph',
        License = 'INTUNE_A',
        Author = 'nicolonsky'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'This test refers to multiple settings.')]
    param(
        # Policy types (operationApprovalPolicyType, such as deviceWipe) of which one policy must exist. Empty accepts any policy.
        [string[]] $RequiredPolicyType
    )

    Write-Verbose 'Testing Multi Admin Approval Policy configuration'
    Write-Verbose 'Retrieving Intune Multi Admin Approval Policies status...'
    $approvalPolicies = @(Invoke-MtGraphRequest -RelativeUri 'deviceManagement/operationApprovalPolicies' -ApiVersion beta | Where-Object { $_ })

    if ($RequiredPolicyType) {
        $matching = @($approvalPolicies | Where-Object { $_.policyType -in $RequiredPolicyType -or $_.policySet.policyType -in $RequiredPolicyType })
        $testResult = $matching.Count -gt 0
        $typeList = ($RequiredPolicyType | ForEach-Object { "``$_``" }) -join ', '
        $testResultMarkdown = if ($testResult) {
            "Well done. An Intune Multi Admin Approval policy of type $typeList is configured.`n"
        } else {
            "No Intune Multi Admin Approval policy of type $typeList is configured.`n"
        }
    } else {
        $testResult = $approvalPolicies.Count -gt 0
        $testResultMarkdown = if ($testResult) {
            "Well done. At least one Intune Multi Admin Approval Policy is configured.`n"
        } else {
            'No Intune Multi Admin Approval Policy is configured.'
        }
    }

    if ($approvalPolicies.Count -gt 0) {
        $testResultMarkdown += "| Name | Type |`n"
        $testResultMarkdown += "| --- | --- |`n"
        foreach ($policy in $approvalPolicies) {
            $testResultMarkdown += "| $(Get-MtSafeMarkdown $policy.displayName) | $($policy.policyType) |`n"
        }
    }
    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
