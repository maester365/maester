function Test-MtCisaSafeLink {
    <#
    .SYNOPSIS
    Checks URL protection for the effective all-recipient Safe Links policy.

    .DESCRIPTION
    URL comparison with a block-list SHOULD be enabled for URLs in emails, Teams messages, and Office documents.

    .EXAMPLE
    Test-MtCisaSafeLink

    Returns true when the active preset or highest-priority all-recipient Safe Links policy enables protection for email, Teams, Office documents, and internal senders.

    .LINK
    https://maester.dev/docs/commands/Test-MtCisaSafeLink
    #>
    [MaesterTest(
        Id = 'CISA.MS.SECURITYSUITE.7.1',
        Title = 'URL comparison with a block-list SHOULD be enabled for URLs in emails, Teams messages, and Office documents.',
        Product = 'exchange',
        RelatedProduct = 'defender',
        Feature = 'safe-links',
        Area = 'email-protection',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = ('T1566.002', 'T1204.001'),
        Control = 'cisa-scuba:MS.SECURITYSUITE.7.1',
        Service = ('ExchangeOnline', 'Graph'),
        License = 'ATP_ENTERPRISE',
        Author = 'soulemike',
        Contributor = 'thomas-s-schmidt'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $policies = @(Get-MtExo -Request SafeLinksPolicy)
    $presetRules = @(Get-MtExo -Request EOPProtectionPolicyRule)
    $safeLinksRules = @(Get-MtExo -Request SafeLinksRule)

    $isEmpty = {
        param($Value)
        $null -eq $Value -or
        ($Value -is [string] -and [string]::IsNullOrWhiteSpace($Value)) -or
        @($Value).Count -eq 0
    }

    $activePresetRules = @(
        $presetRules | Where-Object {
            $_.State -eq 'Enabled' -and
            $_.Identity -match '(?i)(Standard|Strict) Preset Security Policy' -and
            (& $isEmpty $_.SentTo) -and
            (& $isEmpty $_.SentToMemberOf) -and
            (& $isEmpty $_.RecipientDomainIs)
        }
    )

    $selectedPolicy = $null
    $selectedPolicyName = 'Built-In Protection Policy'
    $selectionReason = 'Built-in protection'

    if ($activePresetRules.Count -gt 0) {
        $presetType = if (@($activePresetRules | Where-Object { $_.Identity -match '(?i)Strict Preset Security Policy' }).Count -gt 0) {
            'Strict'
        } else {
            'Standard'
        }
        $selectedPolicy = $policies |
            Where-Object { $_.RecommendedPolicyType -eq $presetType } |
            Select-Object -First 1
        if ($selectedPolicy) {
            $selectedPolicyName = $selectedPolicy.Identity
            $selectionReason = "$presetType preset policy covers all recipients"
        } else {
            $selectedPolicyName = "$presetType preset policy data not returned"
            $selectionReason = 'Enabled all-recipient preset rule'
        }
    } else {
        $allRecipientRules = @(
            $safeLinksRules | Where-Object {
                $_.State -eq 'Enabled' -and
                (& $isEmpty $_.SentTo) -and
                (& $isEmpty $_.SentToMemberOf) -and
                (& $isEmpty $_.RecipientDomainIs)
            }
        )
        if ($allRecipientRules.Count -gt 0) {
            $highestPriority = ($allRecipientRules | Measure-Object -Property Priority -Minimum).Minimum
            $selectedRule = $allRecipientRules |
                Where-Object { $_.Priority -eq $highestPriority } |
                Select-Object -First 1
            $policyReference = $selectedRule.SafeLinksPolicy
            $selectedPolicy = $policies |
                Where-Object { $_.Identity -eq $policyReference -or $_.Name -eq $policyReference } |
                Select-Object -First 1
            $selectedPolicyName = if ($selectedPolicy) { $selectedPolicy.Identity } else { [string]$policyReference }
            $selectionReason = "Highest-priority all-recipient rule (priority $highestPriority)"
        } else {
            $selectedPolicy = $policies |
                Where-Object { $_.Identity -eq 'Built-In Protection Policy' -or $_.Name -eq 'Built-In Protection Policy' } |
                Select-Object -First 1
        }
    }

    $testResult = $null -ne $selectedPolicy -and
        $selectedPolicy.EnableSafeLinksForEmail -eq $true -and
        $selectedPolicy.EnableSafeLinksForTeams -eq $true -and
        $selectedPolicy.EnableSafeLinksForOffice -eq $true -and
        $selectedPolicy.EnableForInternalSenders -eq $true

    $status = if ($testResult) { '✅ Pass' } else { '❌ Fail' }
    $email = if ($selectedPolicy.EnableSafeLinksForEmail -eq $true) { 'Enabled' } else { 'Disabled' }
    $teams = if ($selectedPolicy.EnableSafeLinksForTeams -eq $true) { 'Enabled' } else { 'Disabled' }
    $office = if ($selectedPolicy.EnableSafeLinksForOffice -eq $true) { 'Enabled' } else { 'Disabled' }
    $internal = if ($selectedPolicy.EnableForInternalSenders -eq $true) { 'Enabled' } else { 'Disabled' }
    $result = "| Effective policy | Selection | Email | Teams | Office documents | Internal senders | Result |`n"
    $result += "| --- | --- | --- | --- | --- | --- | --- |`n"
    $result += "| $selectedPolicyName | $selectionReason | $email | $teams | $office | $internal | $status |`n"

    if ($testResult) {
        $message = "Well done. The effective all-recipient Safe Links policy enables URL protection for email, Teams, Office documents, and internal senders.`n`n%TestResult%"
    } else {
        $message = 'Enable Safe Links and internal-sender protection on the effective all-recipient policy. A preset policy applies only when its all-recipient preset rule is enabled; otherwise the highest-priority all-recipient custom rule applies.`n`n%TestResult%'
    }

    Add-MtTestResultDetail -Result ($message -replace '%TestResult%', $result)
    return [bool]$testResult
}
