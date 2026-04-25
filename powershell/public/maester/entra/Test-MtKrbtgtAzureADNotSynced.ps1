function Test-MtKrbtgtAzureADNotSynced {
    <#
    .SYNOPSIS
    Ensure krbtgt_AzureAD is not synchronized from on-premises Active Directory.

    .DESCRIPTION
    The krbtgt_AzureAD account is a sensitive account that should exist only in Entra ID and should not be synchronized from on-premises Active Directory.

    .EXAMPLE
    Test-MtKrbtgtAzureADNotSynced

    Returns true if no synchronized krbtgt_AzureAD account is found in Entra ID.

    .LINK
    https://maester.dev/docs/commands/Test-MtKrbtgtAzureADNotSynced
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (-not (Test-MtConnection Graph)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedGraph
        return $null
    }

    try {
        $OrganizationConfig = Invoke-MtGraphRequest -RelativeUri 'organization'
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }

    if ($OrganizationConfig.onPremisesSyncEnabled -ne $true) {
        Add-MtTestResultDetail -SkippedBecause 'Custom' -SkippedCustomReason 'OnPremisesSynchronization is not configured'
        return $null
    }

    Write-Verbose 'Checking whether krbtgt_AzureAD is synchronized from on-premises Active Directory...'

    try {
        $Select = 'id,displayName,userPrincipalName,mailNickname,onPremisesDistinguishedName,onPremisesSamAccountName'
        $DisplayNameFilter = "onPremisesSyncEnabled eq true and startsWith(displayName,'krbtgt')"
        $UserPrincipalNameFilter = "onPremisesSyncEnabled eq true and startsWith(userPrincipalName,'krbtgt')"
        $MailNicknameFilter = "onPremisesSyncEnabled eq true and startsWith(mailNickname,'krbtgt')"

        Write-Verbose "Querying synchronized users with filter: $DisplayNameFilter"
        $DisplayNameMatches = @(Invoke-MtGraphRequest -RelativeUri 'users' -Filter $DisplayNameFilter -Select $Select)

        Write-Verbose "Querying synchronized users with filter: $UserPrincipalNameFilter"
        $UserPrincipalNameMatches = @(Invoke-MtGraphRequest -RelativeUri 'users' -Filter $UserPrincipalNameFilter -Select $Select)

        Write-Verbose "Querying synchronized users with filter: $MailNicknameFilter"
        $MailNicknameMatches = @(Invoke-MtGraphRequest -RelativeUri 'users' -Filter $MailNicknameFilter -Select $Select)

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

            Add-MtTestResultDetail -Result $TestResultMarkdown
            return $false
        }

        Add-MtTestResultDetail -Result 'Well done. We found no synchronized krbtgt_AzureAD account in Entra ID.'
        return $true
    } catch {
        if ($_.Exception.Response -and $_.Exception.Response.StatusCode -eq 403) {
            Add-MtTestResultDetail -SkippedBecause NotAuthorized
        } else {
            Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        }

        return $null
    }
}
