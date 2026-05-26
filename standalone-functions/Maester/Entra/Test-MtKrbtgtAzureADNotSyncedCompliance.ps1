function Test-MtKrbtgtAzureADNotSyncedCompliance {
    <#
    .SYNOPSIS
    Ensure krbtgt_AzureAD is not synchronized from on-premises Active Directory.

    .DESCRIPTION
    The krbtgt_AzureAD account is a sensitive account that should exist only in Entra ID and should not be synchronized from on-premises Active Directory.
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtKrbtgtAzureADNotSyncedCompliance
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
        $OrganizationConfig = Invoke-MgGraphRequest -Uri 'https://graph.microsoft.com/v1.0/organization'
    } catch {
        return $null
    }

    if ($OrganizationConfig.onPremisesSyncEnabled -ne $true) {
        return $null
    }

    Write-Verbose 'Checking whether krbtgt_AzureAD is synchronized from on-premises Active Directory...'

    try {
        $Select = 'id,displayName,userPrincipalName,mailNickname,onPremisesDistinguishedName,onPremisesSamAccountName'
        $DisplayNameFilter = "onPremisesSyncEnabled eq true and startsWith(displayName,'krbtgt')"
        $UserPrincipalNameFilter = "onPremisesSyncEnabled eq true and startsWith(userPrincipalName,'krbtgt')"
        $MailNicknameFilter = "onPremisesSyncEnabled eq true and startsWith(mailNickname,'krbtgt')"

        Write-Verbose "Querying synchronized users with filter: $DisplayNameFilter"
        $DisplayNameMatches = @(Invoke-MgGraphRequest -Uri 'https://graph.microsoft.com/v1.0/users' -Filter $DisplayNameFilter -Select $Select)

        Write-Verbose "Querying synchronized users with filter: $UserPrincipalNameFilter"
        $UserPrincipalNameMatches = @(Invoke-MgGraphRequest -Uri 'https://graph.microsoft.com/v1.0/users' -Filter $UserPrincipalNameFilter -Select $Select)

        Write-Verbose "Querying synchronized users with filter: $MailNicknameFilter"
        $MailNicknameMatches = @(Invoke-MgGraphRequest -Uri 'https://graph.microsoft.com/v1.0/users' -Filter $MailNicknameFilter -Select $Select)

        $SyncedUsers = @($DisplayNameMatches + $UserPrincipalNameMatches + $MailNicknameMatches | Sort-Object -Property id -Unique)

        $SyncedKrbtgtAzureAdAccounts = @(
            $SyncedUsers | Where-Object {
                $HasKnownNameMatch = @(
                    $_.displayName,
                    $_.mailNickname,
                    $_.onPremisesSamAccountName
                ) -icontains 'krbtgt_AzureAD'

                $UserPrincipalNamePrefix = $null
                if (-not [string]::IsNullOrWhiteSpace($_.userPrincipalName)) {
                    $UserPrincipalNamePrefix = ($_.userPrincipalName -split '@')[0]
                }

                $HasUpnMatch = $UserPrincipalNamePrefix -ieq 'krbtgt_AzureAD'
                $HasDistinguishedNameMatch = $_.onPremisesDistinguishedName -match '(?i)(^|,)CN=krbtgt_AzureAD,'

                $HasKnownNameMatch -or $HasUpnMatch -or $HasDistinguishedNameMatch
            }
        )

        Write-Verbose "Found $($SyncedKrbtgtAzureAdAccounts.Count) synchronized krbtgt_AzureAD account(s)."

        if ($SyncedKrbtgtAzureAdAccounts.Count -gt 0) {
            $TestResultMarkdown = 'At least one synchronized krbtgt_AzureAD account was found in Entra ID. This account should exist only in Entra ID and should not be synchronized from on-premises Active Directory.'
            $TestResultMarkdown += "`n`n| Display Name | User Principal Name | SamAccountName | Distinguished Name |`n"
            $TestResultMarkdown += "| --- | --- | --- | --- |`n"

            foreach ($Account in $SyncedKrbtgtAzureAdAccounts | Sort-Object -Property userPrincipalName, displayName) {
                $DisplayName = if ($Account.displayName) { $Account.displayName } else { '-' }
                $UserPrincipalName = if ($Account.userPrincipalName) { $Account.userPrincipalName } else { '-' }
                $SamAccountName = if ($Account.onPremisesSamAccountName) { $Account.onPremisesSamAccountName } else { '-' }
                $DistinguishedName = if ($Account.onPremisesDistinguishedName) { $Account.onPremisesDistinguishedName } else { '-' }
                $TestResultMarkdown += "| $DisplayName | $UserPrincipalName | $SamAccountName | $DistinguishedName |`n"
            }

            return $false
        }

        return $true
    } catch {
        if ($_.Exception.Response -and $_.Exception.Response.StatusCode -eq 403) {
        } else {
        }

        return $null
    }

}
