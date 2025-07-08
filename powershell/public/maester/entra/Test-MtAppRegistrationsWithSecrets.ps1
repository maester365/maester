<#
.SYNOPSIS
    Check if any service principals are still using secrets instead of certificates or managed identities.

.DESCRIPTION
    It is advised to use certificates or managed identities instead of secrets for service principals. This test checks if any service principals are still using secrets.

.EXAMPLE
    Test-MtAppRegistrationsWithSecrets

    Returns true if no service principals are using secrets, otherwise returns false.

.LINK
    https://maester.dev/docs/commands/Test-MtAppRegistrationsWithSecrets
#>
function Test-MtAppRegistrationsWithSecrets {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'This test checks credentials for all apps.')]
    [OutputType([bool])]
    param(

    )

    if (-not (Test-MtConnection Graph)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedGraph
        return $null
    }

    try {
        $apps = Invoke-MtGraphRequest -RelativeUri 'applications?$select=id,displayName,appId,passwordCredentials' -ErrorAction Stop | Where-Object { $_.passwordCredentials.Count -gt 0 } | Select-Object -Property id, displayName, passwordCredentials, appId
        $return = $apps.Count -eq 0

        if ($return) {
            $testResultMarkdown = 'Well done. No app registrations using secrets.'
        } else {
            $testResultMarkdown = "You have $($apps.Count) app registrations that still use secrets.`n`n%TestResult%"

            Write-Verbose "Found $($apps.Count) app registrations using secrets."
            Write-Verbose 'Creating markdown table for app registrations using secrets.'

            $result = "| ApplicationName | ApplicationId |`n"
            $result += "| --- | --- |`n"
            foreach ($app in $apps) {
                $appMdLink = "[$($app.displayName)](https://entra.microsoft.com/#view/Microsoft_AAD_RegisteredApps/ApplicationMenuBlade/~/Credentials/appId/$($app.appId)/isMSAApp~/false)"
                $result += "| $($appMdLink) | $($app.appId) |`n"
                Write-Verbose "Adding app registration $($app.displayName) with id $($app.appId) to markdown table."
            }
            $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $result
        }

        Add-MtTestResultDetail -Result $testResultMarkdown
        return $return
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
