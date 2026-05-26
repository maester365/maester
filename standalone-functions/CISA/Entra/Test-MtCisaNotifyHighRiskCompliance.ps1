function Test-MtCisaNotifyHighRiskCompliance {
    <#
    .SYNOPSIS
    Checks if Risk Based Policies - MS.AAD.2.2v1 has recipients

    .DESCRIPTION
    A notification SHOULD be sent to the administrator when high-risk users are detected.

    Queries /identityProtection/settings/notifications
    and returns the result of
    (graph/identityProtection/settings/notifications)
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtCisaNotifyHighRiskCompliance
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

    try {
        $sku = Get-MgSubscribedSku | Where-Object { $_.ServicePlans.ServicePlanName -match 'AAD_PREMIUM_P2' }
        if ($null -eq $sku) {
            Write-Verbose "Entra ID P2 license not found"
            return $null
        }
    } catch {
        Write-Verbose "License check failed: $_"
        return $null
    }

    # Phase 2: Data Collection & Phase 3: Compliance Validation
    #Connect-MgGraph -UseDeviceCode -Scopes IdentityRiskEvent.Read.All
    $result = Invoke-MgGraphRequest -Uri 'https://graph.microsoft.com/v1.0/identityProtection/settings/notifications' -ApiVersion "beta"

    $notficationRecipients =  ($result.notificationRecipients + $result.additionalRecipients) | Where-Object {`
            $_.isRiskyUsersAlertsRecipient }

    $testResult = ($notficationRecipients|Measure-Object).Count -ge 1
    return $testResult

}
