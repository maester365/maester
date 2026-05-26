function Test-MtCisaAntiSpamSafeListCompliance {
    <#
    .SYNOPSIS
    Checks state of anti-spam policies

    .DESCRIPTION
    Safe lists SHOULD NOT be enabled.
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtCisaAntiSpamSafeListCompliance
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

    $policy = Get-HostedConnectionFilterPolicy

    $resultPolicy = $policy | Where-Object {`
        -not $_.EnableSafeList
    }

    $testResult = ($resultPolicy|Measure-Object).Count -eq 1
    return $testResult

}
