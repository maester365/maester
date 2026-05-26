function Test-MtCisaAutoExternalForwardingCompliance {
    <#
    .SYNOPSIS
    Checks ...

    .DESCRIPTION
    Automatic forwarding to external domains SHALL be disabled.
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtCisaAutoExternalForwardingCompliance
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

    $domains = Get-RemoteDomain

    $forwardingDomains = $domains | Where-Object { `
        $_.AutoForwardEnabled
    } | Select-Object -Property DomainName

    $testResult = ($forwardingDomains | Measure-Object).Count -eq 0
    # Remote domain does not support deep link
    $result = "| Name | Domain | Automatic forwarding | Test Result |`n"
    $result += "| --- | --- | --- | --- |`n"
    foreach ($item in $domains | Sort-Object -Property Name) {
        $itemState = "Not allow automatic forwarding"
        if ($item.AutoForwardEnabled) {
            $itemState = "Allow automatic forwarding"
        }
    }


    return $testResult

}
