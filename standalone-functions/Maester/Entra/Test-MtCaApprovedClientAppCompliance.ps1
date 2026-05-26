function Test-MtCaApprovedClientAppCompliance {
    <#
    .SYNOPSIS


    .DESCRIPTION

    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtCaApprovedClientAppCompliance
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
    Write-Verbose "Checking for deprecated Approved Client App grant in Conditional Access policies..."
    $policies = Get-MgIdentityConditionalAccessPolicy -All | Where-Object { $_.state -eq "enabled" }
    $policiesResult = New-Object System.Collections.ArrayList

    foreach ($policy in $policies) {
        if ( "approvedApplication" -in ($policy.grantControls.builtInControls) ) {
            $policiesResult.Add($policy) | Out-Null
        }
    }

    # There should be no conditional access policies using the deprecated Approved Client App grant.
    $result = ($policiesResult | Measure-Object).Count -eq 0

    if ($result) {
        $testResult = "Well done! No conditional access use the deprecated Approved Client App grant."
    } else {
    }
    return $result

}
