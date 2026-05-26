function Test-MtExoRejectDirectSendCompliance {
    <#
    .SYNOPSIS
    Checks if direct send is configured to reject

    .DESCRIPTION
    Attackers can exploit direct send to send spam or phishing emails without authentication.
    Direct Send covers anonymous messages (unauthenticated messages) sent from your own domain
    to your organization's mailboxes using the tenant MX
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtExoRejectDirectSendCompliance
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

    try {
        Write-Verbose "Getting Organization..."
        $organizationConfig = Get-OrganizationConfig

        $result = $organizationConfig.RejectDirectSend

        if ($result) {
        } else {
        }

    } catch {
        return $null
    }

    return $result

}
