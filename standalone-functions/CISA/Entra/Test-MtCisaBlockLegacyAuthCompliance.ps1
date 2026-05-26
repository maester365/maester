function Test-MtCisaBlockLegacyAuthCompliance {
    <#
    .SYNOPSIS
    Checks if Baseline Policies Legacy Authentication - MS.AAD.1.1v1 is set to 'blocked'

    .DESCRIPTION
    Legacy authentication SHALL be blocked.
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtCisaBlockLegacyAuthCompliance
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
    try {
        $graphContext = Get-MgContext
        if ($null -eq $graphContext) {
            Write-Verbose "Not connected to Microsoft Graph"
            return $null
        }
    } catch {
        Write-Verbose "Microsoft Graph connection check failed: $_"
        return $null
    }

    # Phase 2: Data Collection & Phase 3: Compliance Validation

    if($EntraIDPlan -eq "Free"){
        return $null
    }

    $result = Get-MgIdentityConditionalAccessPolicy -All | Where-Object { $_.state -eq "enabled" }

    $blockOther = $result | Where-Object {
        $_.grantControls.builtInControls -contains "block" -and
        $_.conditions.clientAppTypes -contains "other" -and
        $_.conditions.users.includeUsers -contains "All" -and
        $_.conditions.applications.includeApplications -contains "All"
    }

    $blockExchangeActiveSync = $result | Where-Object {
        $_.grantControls.builtInControls -contains "block" -and
        $_.conditions.clientAppTypes -contains "exchangeActiveSync" -and
        $_.conditions.users.includeUsers -contains "All" -and
        $_.conditions.applications.includeApplications -contains "All"
    }

    if (($blockOther | Measure-Object).Count -ge 1 -and ($blockExchangeActiveSync | Measure-Object).Count -ge 1) {
        $blockPolicies = @($blockOther) + @($blockExchangeActiveSync)  | Sort-Object id -Unique
    }

    $testResult = ($blockPolicies|Measure-Object).Count -ge 1
    return $testResult

}
