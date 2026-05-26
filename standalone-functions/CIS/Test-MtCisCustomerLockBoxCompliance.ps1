function Test-MtCisCustomerLockBoxCompliance {
    <#
    .SYNOPSIS
    Checks if the customer lockbox feature is enabled

    .DESCRIPTION
    The customer lockbox feature should be enabled
    CIS Microsoft 365 Foundations Benchmark v6.0.1
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtCisCustomerLockBoxCompliance
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
        $exoSession = Get-PSSession | Where-Object { $_.ConfigurationName -eq 'Microsoft.Exchange' -and $_.State -eq 'Opened' }
        if ($null -eq $exoSession) {
            Write-Verbose "Not connected to Exchange Online"
            return $null
        }
    } catch {
        Write-Verbose "Exchange Online connection check failed: $_"
        return $null
    }

    # Phase 2: Data Collection & Phase 3: Compliance Validation

    if ($null -eq $licenseType) {
        return $null
    }

    try {
        Write-Verbose 'Requesting secure scores to get the customer lockbox setting'
        $customerLockbox = Get-OrganizationConfig | Select-Object CustomerLockBoxEnabled

        Write-Verbose 'Checking if the customer lockbox feature is enabled'
        $result = $customerLockbox | Where-Object { $_.CustomerLockBoxEnabled -ne 'True' }

        # Set the result to true and pass if no tenants are found with the customer lockbox feature disabled.
        $testResult = ($result | Measure-Object).Count -eq 0
        # Prepare the markdown result table if the test fails (testResult is false).
        if ($testResult -eq $false) {
        }


        return $testResult
    } catch {
        return $null
    }

}
