function Test-MtAppRegistrationCertificateLifetime {
    <#
    .SYNOPSIS
    Check if app registrations use certificates that are issued with an excessive validity period.

    .DESCRIPTION
    App management policies only constrain credentials that are added after the policy takes effect.
    The restrictForAppsCreatedAfterDateTime property means certificates that already exist are
    grandfathered in and are never re-evaluated, so a tenant can have an app management policy
    enabled and still authenticate with multi-year certificates.

    This test inspects the certificates (keyCredentials) of every app registration and reports the
    ones whose validity period exceeds the maximum. Certificates that have already expired can no
    longer be used to authenticate and are not reported.

    .EXAMPLE
    Test-MtAppRegistrationCertificateLifetime

    Returns true if no app registration uses a certificate that is valid for more than 365 days.

    .EXAMPLE
    Test-MtAppRegistrationCertificateLifetime -MaximumValidityDays 90

    Returns true if no app registration uses a certificate that is valid for more than 90 days.

    .LINK
    https://maester.dev/docs/commands/Test-MtAppRegistrationCertificateLifetime
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # Longest validity period, in days, that a certificate may be issued for. Defaults to 365 days,
        # which matches the asymmetricKeyLifetime of the sample app management policy documented in
        # Test-MtAppManagementPolicyEnabled.
        [ValidateRange(1, 3650)]
        [int] $MaximumValidityDays = 365
    )

    if (-not (Test-MtConnection Graph)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedGraph
        return $null
    }

    try {
        $apps = @(Invoke-MtGraphRequest -RelativeUri 'applications?$select=id,displayName,appId,keyCredentials' -ErrorAction Stop |
                Where-Object { $_.keyCredentials.Count -gt 0 })

        Write-Verbose "Found $($apps.Count) app registrations with certificates."

        $now = Get-Date
        $longLivedCertificates = @()

        foreach ($app in $apps) {
            # A single certificate is listed once per usage (Sign and Verify). Both entries share the
            # thumbprint in customKeyIdentifier, so evaluate each certificate only once.
            $certificates = $app.keyCredentials |
                Group-Object -Property { if ($_.customKeyIdentifier) { $_.customKeyIdentifier } else { $_.keyId } } |
                ForEach-Object { $_.Group | Select-Object -First 1 }

            foreach ($certificate in $certificates) {
                if (-not $certificate.startDateTime -or -not $certificate.endDateTime) { continue }

                $startDateTime = [datetime]$certificate.startDateTime
                $endDateTime = [datetime]$certificate.endDateTime

                # An expired certificate can no longer be used to authenticate and is out of scope.
                if ($endDateTime -lt $now) { continue }

                # Compare the exact lifetime. Rounding first would let a certificate that is
                # valid for slightly longer than the maximum round down and pass.
                $validityPeriod = ($endDateTime - $startDateTime).TotalDays
                if ($validityPeriod -le $MaximumValidityDays) { continue }

                # Round up for display so a reported certificate never reads as being within the maximum.
                $validityDays = [math]::Ceiling($validityPeriod)

                $certificateName = if ([string]::IsNullOrWhiteSpace($certificate.displayName)) {
                    $certificate.keyId
                } else {
                    $certificate.displayName
                }

                Write-Verbose "Certificate $certificateName on $($app.displayName) is valid for $validityDays days."

                $longLivedCertificates += [pscustomobject]@{
                    DisplayName     = $app.displayName
                    AppId           = $app.appId
                    CertificateName = $certificateName
                    ValidityDays    = $validityDays
                    EndDateTime     = $endDateTime
                }
            }
        }

        $return = $longLivedCertificates.Count -eq 0

        if ($return) {
            $testResultMarkdown = 'Well done. No app registration uses a certificate with an excessive validity period.'
        } else {
            $appCount = @($longLivedCertificates.AppId | Select-Object -Unique).Count
            $testResultMarkdown = "You have $($longLivedCertificates.Count) certificate(s) on $appCount app registration(s) that are valid for longer than $MaximumValidityDays days.`n`n%TestResult%"

            $result = "| Application | Certificate | Valid for | Expires |`n"
            $result += "| --- | --- | --- | --- |`n"
            foreach ($certificate in ($longLivedCertificates | Sort-Object -Property ValidityDays -Descending)) {
                $appMdLink = "[$($certificate.DisplayName)](https://entra.microsoft.com/#view/Microsoft_AAD_RegisteredApps/ApplicationMenuBlade/~/Credentials/appId/$($certificate.AppId)/isMSAApp~/false)"
                $result += "| $appMdLink | $($certificate.CertificateName) | $($certificate.ValidityDays) days | $($certificate.EndDateTime.ToString('yyyy-MM-dd')) |`n"
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
