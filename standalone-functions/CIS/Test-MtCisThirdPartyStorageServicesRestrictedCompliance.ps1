function Test-MtCisThirdPartyStorageServicesRestrictedCompliance {
    <#
    .SYNOPSIS
    Checks if users are restricted to store and share files in third-party storage services in Microsoft 365 on the web.

    .DESCRIPTION
    Users should be restricted to store and share files in third-party storage services in Microsoft 365 on the web.
        CIS Microsoft 365 Foundations Benchmark v6.0.1
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtCisThirdPartyStorageServicesRestrictedCompliance
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
        $ServicePrincipal = Invoke-MgGraphRequest -Uri 'https://graph.microsoft.com/v1.0/servicePrincipals' -Filter "appId eq 'c1f33bc0-bdb4-4248-ba9b-096807ddb43e'" -DisableCache

        Write-Verbose 'Executing checks'
        if ($ServicePrincipal) {
            if ($ServicePrincipal.accountEnabled) {
                $testResult = $false
            }
            else {
                $testResult = $true
            }
        }
        else {
            $testResult = $false
        }
        if ($testResult) {
            $ThirdPartyStorageResult = '✅ Pass'
        }
        else {
            $ThirdPartyStorageResult = '❌ Fail'
        }


        return $testResult
    }
    catch {
        return $null
    }

}
