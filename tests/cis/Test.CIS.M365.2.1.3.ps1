function Test-MtCisInternalMalwareNotification {
    <#
    .SYNOPSIS
    Checks if notifications for internal users sending malware are enabled

    .DESCRIPTION
    Notifications for internal users sending malware should be enabled, and an administrator email set
    CIS Microsoft 365 Foundations Benchmark v7.0.0 (2.1.3, L1)

    .EXAMPLE
    Test-MtCisInternalMalwareNotification

    Returns true safe malware notifications are enabled, and an administrator email address is set

    .LINK
    https://maester.dev/docs/commands/Test-MtCisInternalMalwareNotification
    #>
    [MaesterTest(
        Id = 'CIS.M365.2.1.3',
        Title = 'Ensure notifications for internal users sending malware is Enabled',
        Product = 'defender',
        RelatedProduct = 'exchange',
        Feature = 'anti-malware',
        Area = 'email-protection',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = 'T1534',
        Control = ('cis-m365:2.1.3', 'nist-800-53-r5:SI-4(5)'),
        Service = ('ExchangeOnline', 'SecurityCompliance'),
        Author = 'NZLostboy',
        Contributor = ('thomas-s-schmidt', 'Mynster9361')
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Getting anti-malware policies and rules...'
    $policies = @(Get-MtExo -Request MalwareFilterPolicy)
    $customPolicies = @($policies | Where-Object { $_.IsDefault -ne $true })
    $enabledRules = @(Get-MtExo -Request MalwareFilterRule | Where-Object { $_.State -eq 'Enabled' })
    $customPolicyIdentifiers = @($customPolicies | ForEach-Object { $_.Id; $_.Name; $_.Identity } | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
    $customRules = @(
        $enabledRules |
            Where-Object { $_.MalwareFilterPolicy -and $_.MalwareFilterPolicy -in $customPolicyIdentifiers } |
            Sort-Object { [int]$_.Priority }
    )

    $selectedRule = $null
    if ($customRules.Count -gt 0) {
        $selectedRule = $customRules[0]
        $rulePolicy = [string]$selectedRule.MalwareFilterPolicy
        $selectedPolicies = @($customPolicies | Where-Object { $_.Id -eq $rulePolicy -or $_.Name -eq $rulePolicy -or $_.Identity -eq $rulePolicy })
        if ($selectedPolicies.Count -ne 1) {
            Add-MtTestResultDetail -Result "Expected one policy for the highest-priority enabled malware-filter rule '$($selectedRule.Name)', found $($selectedPolicies.Count)."
            return $false
        }
        $policy = $selectedPolicies[0]
        $policySelection = 'highest-priority enabled custom policy'
    } else {
        $defaultPolicies = @($policies | Where-Object { $_.IsDefault -eq $true })
        if ($defaultPolicies.Count -ne 1) {
            Add-MtTestResultDetail -Result "Expected one default anti-malware policy when no enabled custom rule applies, found $($defaultPolicies.Count)."
            return $false
        }
        $policy = $defaultPolicies[0]
        $policySelection = 'default policy'
    }

    $policyName = if ($policy.Name) { $policy.Name } else { $policy.Identity }
    $ruleDescription = if ($selectedRule) { "Rule '$($selectedRule.Name)' (priority $($selectedRule.Priority))" } else { 'Default policy' }
    $addresses = @($policy.InternalSenderAdminAddress | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
    $checks = @(
        [pscustomobject]@{
            CheckName = 'EnableInternalSenderAdminNotifications'
            Value     = $policy.EnableInternalSenderAdminNotifications
            Pass      = $policy.EnableInternalSenderAdminNotifications -eq $true
        }
        [pscustomobject]@{
            CheckName = 'InternalSenderAdminAddress'
            Value     = if ($addresses.Count -gt 0) { $addresses -join ', ' } else { 'Not set' }
            Pass      = $addresses.Count -gt 0
        }
    )
    $testResult = @($checks | Where-Object { -not $_.Pass }).Count -eq 0
    $portalLink = 'https://security.microsoft.com/antimalwarev2'

    if ($testResult) {
        $testResultMarkdown = "Well done. The $policySelection '$policyName' has internal malware notifications and a configured administrator address ($portalLink).`n`n%TestResult%"
    } else {
        $testResultMarkdown = "The $policySelection '$policyName' does not have internal malware notifications and a nonblank administrator address configured ($portalLink).`n`n%TestResult%"
    }

    $resultMd = "| Policy | Rule | Setting | Value | Result |`n"
    $resultMd += "| --- | --- | --- | --- | --- |`n"
    foreach ($check in $checks) {
        $itemResult = if ($check.Pass) { '✅ Pass' } else { '❌ Fail' }
        $resultMd += "| $policyName | $ruleDescription | $($check.CheckName) | $($check.Value) | $itemResult |`n"
    }

    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $resultMd
    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
