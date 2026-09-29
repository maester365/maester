function Test-MtAppRegistrationCredentialExpiry {
    <#
    .SYNOPSIS
    Check if app registrations have credentials that are expired or about to expire.

    .DESCRIPTION
    An expired certificate or secret can no longer authenticate, but it stays on the app
    registration until someone removes it. Expired credentials accumulate, obscure which
    credential a workload actually uses, and make it harder to spot one that was added by an
    attacker. Microsoft Entra recommends removing unused credentials from applications.

    A credential that is about to expire is the same problem shortly before it happens: the
    workload keeps running until the credential lapses, and the outage arrives without warning.

    This test inspects the certificates (keyCredentials) and secrets (passwordCredentials) of
    every app registration and reports the ones that have already expired or that expire within
    the next ExpiringWithinDays days.

    .EXAMPLE
    Test-MtAppRegistrationCredentialExpiry

    Returns true if no app registration has a credential that is expired or expires within 30 days.

    .EXAMPLE
    Test-MtAppRegistrationCredentialExpiry -ExpiringWithinDays 7

    Returns true if no app registration has a credential that is expired or expires within 7 days.

    .LINK
    https://maester.dev/docs/commands/Test-MtAppRegistrationCredentialExpiry
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # Number of days ahead to look for credentials that are about to expire. Defaults to 30 days,
        # matching the threshold used by Test-MtApplePushNotificationCertificate.
        [ValidateRange(1, 365)]
        [int] $ExpiringWithinDays = 30
    )

    if (-not (Test-MtConnection Graph)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedGraph
        return $null
    }

    try {
        $apps = @(Invoke-MtGraphRequest -RelativeUri 'applications?$select=id,displayName,appId,keyCredentials,passwordCredentials' -ErrorAction Stop |
                Where-Object { $_.keyCredentials.Count -gt 0 -or $_.passwordCredentials.Count -gt 0 })

        Write-Verbose "Found $($apps.Count) app registrations with credentials."

        $now = Get-Date
        $affectedCredentials = @()

        foreach ($app in $apps) {
            # A single certificate is listed once per usage (Sign and Verify). Both entries share the
            # thumbprint in customKeyIdentifier, so evaluate each certificate only once. Secrets have
            # no thumbprint and are always distinct.
            $certificates = @($app.keyCredentials |
                    Group-Object -Property { if ($_.customKeyIdentifier) { $_.customKeyIdentifier } else { $_.keyId } } |
                    ForEach-Object { $_.Group | Select-Object -First 1 })

            $credentials = @(
                $certificates | ForEach-Object { [pscustomobject]@{ Type = 'Certificate'; Credential = $_ } }
                @($app.passwordCredentials) | ForEach-Object { [pscustomobject]@{ Type = 'Secret'; Credential = $_ } }
            )

            foreach ($entry in $credentials) {
                $credential = $entry.Credential
                if (-not $credential -or -not $credential.endDateTime) { continue }

                $endDateTime = [datetime]$credential.endDateTime

                # Round up, matching Test-MtApplePushNotificationCertificate: a credential with
                # 2.5 days left reads as 3 days, and one that lapsed 2.5 days ago reads as 2 days
                # rather than drifting by a day for every partial day.
                $daysUntilExpiry = [math]::Ceiling(($endDateTime - $now).TotalDays)

                $status = if ($endDateTime -lt $now) {
                    "Expired $([math]::Abs($daysUntilExpiry)) day(s) ago"
                } elseif ($daysUntilExpiry -le $ExpiringWithinDays) {
                    "Expires in $daysUntilExpiry day(s)"
                } else {
                    continue
                }

                $credentialName = if ([string]::IsNullOrWhiteSpace($credential.displayName)) {
                    $credential.keyId
                } else {
                    $credential.displayName
                }

                Write-Verbose "$($entry.Type) $credentialName on $($app.displayName): $status."

                $affectedCredentials += [pscustomobject]@{
                    DisplayName    = $app.displayName
                    AppId          = $app.appId
                    Type           = $entry.Type
                    CredentialName = $credentialName
                    EndDateTime    = $endDateTime
                    Status         = $status
                }
            }
        }

        $return = $affectedCredentials.Count -eq 0

        if ($return) {
            $testResultMarkdown = 'Well done. No app registration has a credential that is expired or about to expire.'
        } else {
            $appCount = @($affectedCredentials.AppId | Select-Object -Unique).Count
            $testResultMarkdown = "You have $($affectedCredentials.Count) credential(s) on $appCount app registration(s) that are expired or expire within $ExpiringWithinDays days.`n`n%TestResult%"

            $result = "| Application | Type | Credential | Expires | Status |`n"
            $result += "| --- | --- | --- | --- | --- |`n"
            foreach ($credential in ($affectedCredentials | Sort-Object -Property EndDateTime)) {
                $appMdLink = "[$(Get-MtSafeMarkdown $credential.DisplayName)](https://entra.microsoft.com/#view/Microsoft_AAD_RegisteredApps/ApplicationMenuBlade/~/Credentials/appId/$($credential.AppId)/isMSAApp~/false)"
                $result += "| $appMdLink | $($credential.Type) | $($credential.CredentialName) | $($credential.EndDateTime.ToString('yyyy-MM-dd')) | $($credential.Status) |`n"
            }
            $testResultMarkdown = $testResultMarkdown.Replace('%TestResult%', $result)
        }

        Add-MtTestResultDetail -Result $testResultMarkdown
        return $return
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
