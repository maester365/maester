function Test-MtCaAzureDevOpsCompliance {
    <#
    .SYNOPSIS


    .DESCRIPTION

    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtCaAzureDevOpsCompliance
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
    Write-Verbose "Checking for Conditional Access policies that explicitly include Azure DevOps..."

    $policies = Get-MgIdentityConditionalAccessPolicy -All | Where-Object { $_.state -eq "enabled" }
    $policiesResult = New-Object System.Collections.ArrayList
    $result = $false

    $azureDevOpsAppId = '499b84ac-1321-427f-aa17-267ca6975798'
    foreach ($policy in $policies) {
        if ( $azureDevOpsAppId -in ($policy.conditions.applications.includeApplications) ) {
            $result = $true
            $policiesResult.Add($policy) | Out-Null
        }
    }
    if (($policiesResult | Measure-Object).Count -ne 0) {
    } else {
        $testResult = "There are no conditional access policies that explicitly target Azure DevOps."
    }
    return $result

}
