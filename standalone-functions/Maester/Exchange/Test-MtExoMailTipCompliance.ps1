function Test-MtExoMailTipCompliance {
    <#
    .SYNOPSIS
    Checks if MailTips are enabled for end users

    .DESCRIPTION
    MailTips assist end users with identifying strange patterns to emails they send.
    This helps protect against accidental information disclosure and phishing attempts.
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtExoMailTipCompliance
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
        Write-Verbose "Getting Organization Config..."
        $organizationConfig = Get-OrganizationConfig

        $result = $organizationConfig.MailTipsExternalRecipientsTipsEnabled

        if ($result) {
        } else {
        }

    } catch {
        return $null
    }

    return $result

}
