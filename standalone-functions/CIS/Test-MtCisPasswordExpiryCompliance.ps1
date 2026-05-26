function Test-MtCisPasswordExpiryCompliance {
    <#
    .SYNOPSIS
    Checks if passwords are set to expire

    .DESCRIPTION
    Passwords should not be set to expire
    CIS Microsoft 365 Foundations Benchmark v6.0.1
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtCisPasswordExpiryCompliance
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
        Write-Verbose 'Get domain details for the password expiry period'
        $domains = Invoke-MgGraphRequest -Uri 'https://graph.microsoft.com/v1.0/domains'

        Write-Verbose 'Get verified and managed domains where passwords are set to expire'

        $noPasswordExpiryPeriodInDays = [int]::MaxValue

        $excludedDomains = @()
        $applicableDomains = @()
        foreach ($domain in $domains) {
            # Password policy checks apply only to managed and verified domains.
            if (($domain.authenticationType -ne "Managed") -or ($domain.isVerified -ne $true)) {
                $excludedDomains += $domain
                continue
            }

            $applicableDomains += $domain
        }

        $result = $applicableDomains | Where-Object {
            $passwordValidityPeriodInDays = 0
            $domainPasswordValidityPeriodInDays = $_.PasswordValidityPeriodInDays
            # If null or a boolean, the password expiry period is not set, and passwords do not expire.
            # Return false to indicate this domain does not fail the test.
            if (($null -eq $domainPasswordValidityPeriodInDays) -or ($domainPasswordValidityPeriodInDays -is [bool])) {
                return $false
            }
            if (-not [int]::TryParse($domainPasswordValidityPeriodInDays.ToString(), [ref]$passwordValidityPeriodInDays)) {
                return $false
            }
            # If valid integer, check if equal to the value that indicates no password expiry (MaxValue).
            return $passwordValidityPeriodInDays -ne $noPasswordExpiryPeriodInDays
        }

        $testResult = ($result | Measure-Object).Count -eq 0
        foreach ($item in $domains) {
            if ($item.id -in $excludedDomains.id) {
            } elseif ($item.id -notin $result.id) {
            }
        }


        return $testResult
    } catch {
        return $null
    }

}
