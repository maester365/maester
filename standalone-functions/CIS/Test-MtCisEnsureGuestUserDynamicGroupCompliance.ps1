function Test-MtCisEnsureGuestUserDynamicGroupCompliance {
    <#
    .SYNOPSIS
    Checks if minimum one dynamic group exists with a membership rule targeting guest users.

    .DESCRIPTION
    There should be minimum one dynamic group with a membership rule targeting guest users to ensure that guest users are easily identifiable and can be managed effectively.
        CIS Microsoft 365 Foundations Benchmark v6.0.1
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtCisEnsureGuestUserDynamicGroupCompliance
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

    try {
        Write-Verbose 'Getting settings...'
        $groups = Invoke-MgGraphRequest -Uri 'https://graph.microsoft.com/v1.0/groups' -DisableCache | Where-Object { $_.groupTypes -contains "DynamicMembership" }

        Write-Verbose 'Executing checks'
        $checkGuestUserGroup = $groups | Where-Object { $_.MembershipRule -like "*(user.userType -eq `"Guest`")*" }

        $testResult = (($checkGuestUserGroup | Measure-Object).Count -ge 1)
        return $testResult
    }
    catch {
        return $null
    }

}
