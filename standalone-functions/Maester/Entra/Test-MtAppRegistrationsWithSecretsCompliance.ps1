function Test-MtAppRegistrationsWithSecretsCompliance {
    <#
    .SYNOPSIS
    Check if any service principals are still using secrets instead of certificates or managed identities.

    .DESCRIPTION
    It is advised to use certificates or managed identities instead of secrets for service principals. This test checks if any service principals are still using secrets.
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtAppRegistrationsWithSecretsCompliance
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
        $apps = Invoke-MgGraphRequest -Uri 'https://graph.microsoft.com/v1.0/applications?$select=id,displayName,appId,passwordCredentials' -ErrorAction Stop | Where-Object { $_.passwordCredentials.Count -gt 0 } | Select-Object -Property id, displayName, passwordCredentials, appId
        $return = $apps.Count -eq 0

        if ($return) {
        } else {

            Write-Verbose "Found $($apps.Count) app registrations using secrets."
            Write-Verbose 'Creating markdown table for app registrations using secrets.'

            $result = "| ApplicationName | ApplicationId |`n"
            $result += "| --- | --- |`n"
            foreach ($app in $apps) {
                $appMdLink = "[$($app.displayName)](https://entra.microsoft.com/#view/Microsoft_AAD_RegisteredApps/ApplicationMenuBlade/~/Credentials/appId/$($app.appId)/isMSAApp~/false)"
                $result += "| $($appMdLink) | $($app.appId) |`n"
                Write-Verbose "Adding app registration $($app.displayName) with id $($app.appId) to markdown table."
            }
        }

        return $return
    } catch {
        return $null
    }

}
