function Test-MtCisaPhishResistantCompliance {
    <#
    .SYNOPSIS
    Checks if Conditional Access Policy using Phishing-Resistant Authentication Strengths is enabled

    .DESCRIPTION
    Phishing-resistant MFA SHALL be enforced for all users
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtCisaPhishResistantCompliance
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

    $policies = $result | Where-Object {`
        $_.conditions.applications.includeApplications -contains "All" -and `
        $_.conditions.users.includeUsers -contains "All" -and `
        $_.grantControls.authenticationStrength.displayName -eq "Phishing-resistant MFA" }

    $testResult = ($policies|Measure-Object).Count -ge 1
    return $testResult

}
