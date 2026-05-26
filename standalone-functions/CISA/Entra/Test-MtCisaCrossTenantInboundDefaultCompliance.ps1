function Test-MtCisaCrossTenantInboundDefaultCompliance {
    <#
    .SYNOPSIS
    Checks cross-tenant default inbound access configuration

    .DESCRIPTION
    Guest invites SHOULD only be allowed to specific external domains that have been authorized by the agency for legitimate business purposes.
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtCisaCrossTenantInboundDefaultCompliance
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

    $policy = Invoke-MgGraphRequest -Uri 'https://graph.microsoft.com/v1.0/policies/crossTenantAccessPolicy/default'

    $testResult = ($policy | Where-Object {`
        $_.b2bCollaborationInbound.usersAndGroups.accessType -eq "blocked" -and `
        $_.b2bCollaborationInbound.applications.accessType -eq "blocked"
    }|Measure-Object).Count -eq 1
    $result = "| External Users & Groups | Applications |`n"
    $result += "| --- | --- |`n"
    $usersAndGroups = $applications = "❌ Fail"
    if($policy.b2bCollaborationInbound.usersAndGroups.accessType -eq "blocked"){
    }
    if($policy.b2bCollaborationInbound.applications.accessType -eq "blocked"){
    }
    $result += "| $usersAndGroups | $applications |`n"


    return $testResult

}
