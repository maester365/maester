﻿<#
.SYNOPSIS
    Checks if Risk Based Policies - MS.AAD.2.2v1 has recipients

.DESCRIPTION

    A notification SHOULD be sent to the administrator when high-risk users are detected.

    Queries /identityProtection/settings/notifications
    and returns the result of
     (graph/identityProtection/settings/notifications)

.EXAMPLE
    Test-MtCisaNotifyHighRisk

    Returns the result of (graph.microsoft.com/beta/identityProtection/settings/notifications)
#>

Function Test-MtCisaNotifyHighRisk {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    #Connect-MgGraph -UseDeviceCode -Scopes IdentityRiskEvent.Read.All
    $result = Invoke-MtGraphRequest -RelativeUri "identityProtection/settings/notifications" -ApiVersion "beta"

    $notficationRecipients = $result.notificationRecipients | Where-Object {`
            $_.isRiskyUsersAlertsRecipient }

    $testResult = ($notficationRecipients|Measure-Object).Count -ge 1

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant has one or more recipients for notifications of risky user logins:`n`n%TestResult%"
    } else {
        $testResultMarkdown = "Your tenant does not have any recipients for notifications of risky user logins."
    }
    Add-MtTestResultDetail -Result $testResultMarkdown -GraphObjectType IdentityProtection -GraphObjects $notficationRecipients

    return $testResult
}