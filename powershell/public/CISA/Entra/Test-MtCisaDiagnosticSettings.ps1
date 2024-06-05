<#
.SYNOPSIS
    Checks for configuration of Entra diagnostic settings

.DESCRIPTION

    Security logs SHALL be sent to the agency's security operations center for monitoring.

.EXAMPLE
    Test-MtCisaDiagnosticSettings

    Returns true if diagnostic settings for the appropriate logs are configured

#>

Function Test-MtCisaDiagnosticSettings {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $actual = $logs = @{
        "AuditLogs" = $false
        "SignInLogs" = $false
        "RiskyUsers" = $false
        "UserRiskEvents" = $false
        "NonInteractiveUserSignInLogs" = $false
        "ServicePrincipalSignInLogs" = $false
        "ADFSSignInLogs" = $false
        "RiskyServicePrincipals" = $false
        "ServicePrincipalRiskEvents" = $false
        "EnrichedOffice365AuditLogs" = $false
        "MicrosoftGraphActivityLogs" = $false
        "ManagedIdentitySignInLogs" = $false
        "ProvisioningLogs" = $false
    }
    $configs = @()

    $settings = Invoke-AzRestMethod -Path "/providers/microsoft.aadiam/diagnosticSettings?api-version=2017-04-01-preview"
    $settings = ($settings.Content|ConvertFrom-Json).value

    $settings | ForEach-Object { `
        $config = [PSCustomObject]@{
            name = $_.name
        }
        $_.properties.logs | ForEach-Object { `
            $config | Add-Member -MemberType NoteProperty -Name $_.category -Value $_.enabled
        }
        $configs += $config
    }

    foreach($log in $logs.Keys){
        if($configs.$log){
            $actual.$log = $true
        }
    }

    $unsetLogs = $actual.Keys | Where-Object { `
        $actual["$_"] -eq $false
    } | Sort-Object

    $testResult = $unsetLogs.Count -eq 0

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant has diagnostic settings configured for all logs."
    } else {
        $testResultMarkdown = "Your tenant does not have diagnostic settings configured for all logs:`n`n%unsetLogs%"
    }
    Add-MtTestResultDetail -Result $testResultMarkdown -GraphObjectType DiagnosticSettings

    return $testResult
}