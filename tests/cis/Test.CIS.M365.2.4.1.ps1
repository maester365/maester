function Test-MtCisPriorityAccountProtection {
    <#
    .SYNOPSIS
        Checks that priority account protection is on, priority accounts are tagged and alerts exist for malware and phishing.

    .DESCRIPTION
        Checks that priority account protection is enabled, at least one priority account is defined, and alert policies exist for high severity inbound malware and phishing that apply to the Priority account tag and notify users.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (2.4.1, L1)

    .EXAMPLE
        Test-MtCisPriorityAccountProtection

        Returns true if priority account protection is enabled and configured.

    .LINK
        https://maester.dev/docs/tests/CIS.M365.2.4.1
    #>
    [MaesterTest(
        Id = 'CIS.M365.2.4.1',
        Title = 'Ensure Priority account protection is enabled and configured',
        Product = 'defender',
        Feature = 'tenant-settings',
        Area = 'email-protection',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Medium',
        Mitre = 'T1566',
        Control = ('cis-m365:2.4.1', 'nist-800-53-r5:SI-4(5)'),
        Service = ('ExchangeOnline', 'SecurityCompliance'),
        License = 'THREAT_INTELLIGENCE',
        Author = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Getting priority account protection settings...'
    $tenantSettings = Get-MtExo -Request EmailTenantSettings
    $vipUsers = @(Get-MtExo -Request VipUser)
    $alerts = @(Get-MtExo -Request ProtectionAlert | Where-Object { $_.RecipientTags -match 'Priority account' })

    $report = foreach ($alert in $alerts) {
        $checks = [ordered]@{
            'Threat type' = $alert.ThreatType -eq 'Malware' -or $alert.ThreatType -eq 'Phish'
            'Severity high' = $alert.Severity -eq 'High'
            'Inbound mail' = [bool]($alert.Filter -match "Mail.Direction -eq 'Inbound'")
            'Priority account tag' = [bool]($alert.RecipientTags -match 'Priority account')
            'Notification enabled' = $alert.NotificationEnabled -eq $true
            'Notify user' = [bool]$alert.NotifyUser
            'Enabled' = $alert.Disabled -eq $false
        }
        $failedChecks = @($checks.GetEnumerator() | Where-Object { -not $_.Value } | ForEach-Object { $_.Key })
        [pscustomobject]@{ Name = $alert.Name; ThreatType = $alert.ThreatType; Failed = $failedChecks -join ', '; Pass = $failedChecks.Count -eq 0 }
    }
    $malwareOk = @($report | Where-Object { $_.Pass -and $_.ThreatType -eq 'Malware' }).Count -ge 1
    $phishOk = @($report | Where-Object { $_.Pass -and $_.ThreatType -eq 'Phish' }).Count -ge 1
    $protectionEnabled = $tenantSettings.EnablePriorityAccountProtection -eq $true
    $testResult = $protectionEnabled -and $vipUsers.Count -ge 1 -and $malwareOk -and $phishOk

    $passText = 'Priority account protection is enabled and configured.'
    $failText = 'Priority account protection is not fully enabled and configured.'

    $resultMd = "| Requirement | Value | Result |`n"
    $resultMd += "| --- | --- | --- |`n"
    $resultMd += "| Priority account protection enabled | $($tenantSettings.EnablePriorityAccountProtection) | $(if ($protectionEnabled) { '✅ Pass' } else { '❌ Fail' }) |`n"
    $resultMd += "| Priority accounts defined | $($vipUsers.Count) | $(if ($vipUsers.Count -ge 1) { '✅ Pass' } else { '❌ Fail' }) |`n"
    $resultMd += "| Compliant malware alert | $(@($report | Where-Object { $_.ThreatType -eq 'Malware' }).Count) found | $(if ($malwareOk) { '✅ Pass' } else { '❌ Fail' }) |`n"
    $resultMd += "| Compliant phishing alert | $(@($report | Where-Object { $_.ThreatType -eq 'Phish' }).Count) found | $(if ($phishOk) { '✅ Pass' } else { '❌ Fail' }) |`n"

    if ($testResult) {
        $testResultMarkdown = "Well done. $passText`n`n%TestResult%"
    } else {
        $testResultMarkdown = "$failText`n`n%TestResult%"
    }
    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $resultMd

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
