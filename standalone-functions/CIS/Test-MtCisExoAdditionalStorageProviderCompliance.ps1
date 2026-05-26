function Test-MtCisExoAdditionalStorageProviderCompliance {
    <#
    .SYNOPSIS
    Checks if additional storage providers are restricted in Outlook on the web

    .DESCRIPTION
    This setting allows users to open certain external files while working in Outlook on the web.
    If allowed, keep in mind that Microsoft doesn't control the use terms or privacy policies of
    those third-party services.
    CIS Microsoft 365 Foundations Benchmark v6.0.1
    6.5.3 (L2) Ensure additional storage providers are restricted in Outlook on the web (Automated)
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtCisExoAdditionalStorageProviderCompliance
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
        Write-Verbose "Getting OWA Mailbox Policy..."
        $owaMailboxPolicy = Get-OwaMailboxPolicy
        Write-Verbose "Found $($owaMailboxPolicy.Count) Exchange Web mailbox policies"


        $owaMailboxPolicyDefault = $owaMailboxPolicy | Where-Object { $_.IsDefault -eq $true }
        Write-Verbose "Filtered $(@($owaMailboxPolicyDefault).Count) Default Web mailbox policy"

        if ($null -eq $owaMailboxPolicyDefault) {
            return $null
        }

        $result = $owaMailboxPolicyDefault.AdditionalStorageProvidersAvailable

        if ($result -eq $false) {
        } else {
        }

    } catch {
        return $null
    }

    return !$result

}
