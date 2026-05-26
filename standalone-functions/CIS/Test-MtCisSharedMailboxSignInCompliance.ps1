function Test-MtCisSharedMailboxSignInCompliance {
    <#
    .SYNOPSIS
    Checks if shared mailboxes allow sign-ins

    .DESCRIPTION
    Ensure Sign ins are blocked for shared mailboxes.
    CIS Microsoft 365 Foundations Benchmark v6.0.1
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtCisSharedMailboxSignInCompliance
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
        Write-Verbose 'Getting all shared mailboxes'
        $sharedMailboxes = Get-EXOSharedMailbox -ErrorAction Stop
    }
    catch {
        return $null
    }

    if (($sharedMailboxes | Measure-Object).Count -eq 0) {
        return $null
    }

    try {
        Write-Verbose 'For each mailbox get mailbox and AccountEnabled status'
        $mgUsers = Invoke-MgGraphRequest -Uri 'https://graph.microsoft.com/v1.0/users' -UniqueId @($sharedMailboxes.ExternalDirectoryObjectId) -Select id, displayName, userPrincipalName, accountEnabled
        $mailboxDetails = foreach ($mgUser in $mgUsers) {
            $mgUser | Select-Object DisplayName, UserPrincipalName, AccountEnabled
        }

        Write-Verbose 'Select shared mailboxes where sign-in is enabled'
        $result = $mailboxDetails | Where-Object { $_.AccountEnabled -eq 'True' }
        $resultCount = ($result | Measure-Object).Count

        $testResult = if ($resultCount -eq 0) { $true } else { $false }
        return $testResult
    }
    catch {
        return $null
    }

}
