<#
.SYNOPSIS
    Check for the usage of Intune Multi Admin Approval Policies

.DESCRIPTION
    At least one Intune Multi Admin Approval Policy should be configured

.EXAMPLE
    Test-MtOperationApprovalPolicies

    Returns true if at least one Intune Multi Admin Approval Policy is configured, false if none is configured.

.LINK
    https://maester.dev/docs/commands/Test-MtOperationApprovalPolicies
#>
function Test-MtOperationApprovalPolicies {
    [CmdletBinding()]
    [OutputType([bool])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'This test refers to multiple settings.')]
    param()

    Write-Verbose 'Testing Multi Admin Approval Policy configuration'
    if (-not (Get-MtLicenseInformation -Product Intune)) {
        Add-MtTestResultDetail -SkippedBecause NotLicensedIntune
        return $null
    }

    try {
        Write-Verbose 'Retrieving Intune Multi Admin Approval Policies status...'
        $approvalPolicies = Invoke-MtGraphRequest -RelativeUri 'deviceManagement/operationApprovalPolicies' -ApiVersion beta
        $testResultMarkdown = ''
        $hasPolicies = -not($approvalPolicies -is [array] -and $approvalPolicies.Count -eq 0)
        if ($hasPolicies) {
            $testResultMarkdown += "Well done. At least one Intune Multi Admin Approval Policy is configured.`n"
            $testResultMarkdown += "| Name | Type |`n"
            $testResultMarkdown += "| --- | --- |`n"
            foreach ($policy in $approvalPolicies) {
                $testResultMarkdown += "| $($policy.displayName) | $($policy.policyType) |`n"
            }
        } else {
            $testResultMarkdown += 'No Intune Multi Admin Approval Policy is configured.'
        }
        Add-MtTestResultDetail -Result $testResultMarkdown
        return $hasPolicies
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
