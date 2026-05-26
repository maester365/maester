function Test-MtOperationApprovalPoliciesCompliance {
    <#
    .SYNOPSIS
    Check for the usage of Intune Multi Admin Approval Policies

    .DESCRIPTION
    At least one Intune Multi Admin Approval Policy should be configured
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtOperationApprovalPoliciesCompliance
    if ($result -eq $true) { Write-Host "Compliant" }
    elseif ($result -eq $false) { Write-Host "Non-Compliant" }
    else { Write-Host "Skipped or Error" }

    .OUTPUTS
    bool|null - Returns true if compliant, false if non-compliant, null if skipped or error
    #>
    [CmdletBinding()]
    [OutputType([bool], [nullable])]
    param()

    # Phase 1: Prerequisites Check
    # Phase 2: Data Collection & Phase 3: Compliance Validation
    Write-Verbose 'Testing Multi Admin Approval Policy configuration'

    try {
        Write-Verbose 'Retrieving Intune Multi Admin Approval Policies status...'
        $approvalPolicies = Invoke-MgGraphRequest -Uri 'https://graph.microsoft.com/beta/deviceManagement/operationApprovalPolicies'
        $hasPolicies = @($approvalPolicies).Count -gt 0
        if ($hasPolicies) {
        } else {
        }
        return $hasPolicies
    } catch {
        return $null
    }

}
