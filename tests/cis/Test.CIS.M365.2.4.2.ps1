function Test-MtCisStrictPresetForPriorityAccount {
    <#
    .SYNOPSIS
        Checks that both Strict preset security policy rules are enabled and apply to every priority account.

    .DESCRIPTION
        Checks that both the Exchange Online Protection and the Defender for Office 365 rules of the Strict preset security policy are enabled, have at least one recipient condition (SentTo, SentToMemberOf or RecipientDomainIs), and that every user tagged as a priority account meets those conditions and is not excluded by an exception.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (2.4.2, L1)

    .EXAMPLE
        Test-MtCisStrictPresetForPriorityAccount

        Returns true if both Strict preset security policy rules are enabled and apply to every priority account.

    .LINK
        https://maester.dev/docs/tests/CIS.M365.2.4.2
    #>
    [MaesterTest(
        Id = 'CIS.M365.2.4.2',
        Title = 'Ensure Priority accounts have ''Strict protection'' presets applied',
        Product = 'defender',
        Feature = 'tenant-settings',
        Area = 'email-protection',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = 'T1566',
        Control = ('cis-m365:2.4.2', 'nist-800-53-r5:SI-4(5)'),
        Service = ('ExchangeOnline', 'Graph'),
        License = 'ATP_ENTERPRISE',
        Author = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Getting preset security policy rules and priority accounts...'
    $eopRule = @(Get-MtExo -Request EOPProtectionPolicyRule) | Where-Object { $_.Identity -eq 'Strict Preset Security Policy' } | Select-Object -First 1
    $atpRule = @(Get-MtExo -Request ATPProtectionPolicyRule) | Where-Object { $_.Identity -eq 'Strict Preset Security Policy' } | Select-Object -First 1
    $rules = @(
        [pscustomobject]@{ Name = 'Exchange Online Protection'; Rule = $eopRule }
        [pscustomobject]@{ Name = 'Defender for Office 365'; Rule = $atpRule }
    )
    $vipUsers = @(Get-MtExo -Request VipUser)

    $usesGroups = @($rules.Rule | Where-Object { $_ } | Where-Object {
            @($_.SentToMemberOf | Where-Object { $_ }).Count -gt 0 -or @($_.ExceptIfSentToMemberOf | Where-Object { $_ }).Count -gt 0
        }).Count -gt 0

    # Rule values can be names, addresses or GUIDs, so each one is also resolved to its Entra object ID.
    $recipientIds = @{}
    $resolveIds = {
        param([object[]] $Values)
        foreach ($value in @($Values | Where-Object { $_ })) {
            $key = "$value"
            if (-not $recipientIds.ContainsKey($key)) {
                $recipient = Get-Recipient -Identity $key -ErrorAction SilentlyContinue | Select-Object -First 1
                $recipientIds[$key] = "$($recipient.ExternalDirectoryObjectId)"
            }
            $key
            if ($recipientIds[$key]) { $recipientIds[$key] }
        }
    }
    $matchesAny = {
        param([object[]] $Candidates, $Set)
        @($Candidates | Where-Object { $_ -and $Set.Contains("$_") }).Count -gt 0
    }
    $matchesDomain = {
        param([object[]] $Domains, [string] $Domain)
        @($Domains | Where-Object { $_ -and ($Domain -eq "$_" -or $Domain -like "*.$_") }).Count -gt 0
    }

    $priorityAccounts = @(foreach ($vip in $vipUsers) {
            $keys = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
            foreach ($value in @($vip.Name, $vip.DisplayName, $vip.UserPrincipalName, $vip.WindowsEmailAddress, $vip.Identity, $vip.DistinguishedName, $vip.ExternalDirectoryObjectId, $vip.Guid)) {
                if ("$value") { $null = $keys.Add("$value") }
            }
            $groupKeys = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
            if ($usesGroups -and $vip.ExternalDirectoryObjectId) {
                $groups = @(Invoke-MtGraphRequest -ApiVersion 'v1.0' -RelativeUri "users/$($vip.ExternalDirectoryObjectId)/transitiveMemberOf/microsoft.graph.group" -Select @('id', 'displayName', 'mail', 'mailNickname'))
                foreach ($group in $groups) {
                    foreach ($value in @($group.id, $group.displayName, $group.mail, $group.mailNickname)) {
                        if ("$value") { $null = $groupKeys.Add("$value") }
                    }
                }
            }
            $address = if ($vip.WindowsEmailAddress) { "$($vip.WindowsEmailAddress)" } else { "$($vip.UserPrincipalName)" }
            [pscustomobject]@{
                Name      = if ($vip.UserPrincipalName) { "$($vip.UserPrincipalName)" } else { "$($vip.Name)" }
                Keys      = $keys
                GroupKeys = $groupKeys
                Domain    = ($address -split '@')[-1]
            }
        })

    # Different recipient conditions of a preset rule are combined with AND, and any exception excludes the recipient.
    $isCovered = {
        param($Rule, $Account)
        $conditions = @()
        if (@($Rule.SentTo | Where-Object { $_ }).Count -gt 0) {
            $conditions += & $matchesAny (& $resolveIds $Rule.SentTo) $Account.Keys
        }
        if (@($Rule.SentToMemberOf | Where-Object { $_ }).Count -gt 0) {
            $conditions += & $matchesAny (& $resolveIds $Rule.SentToMemberOf) $Account.GroupKeys
        }
        if (@($Rule.RecipientDomainIs | Where-Object { $_ }).Count -gt 0) {
            $conditions += & $matchesDomain $Rule.RecipientDomainIs $Account.Domain
        }
        $excluded = (& $matchesAny (& $resolveIds $Rule.ExceptIfSentTo) $Account.Keys) -or
            (& $matchesAny (& $resolveIds $Rule.ExceptIfSentToMemberOf) $Account.GroupKeys) -or
            (& $matchesDomain $Rule.ExceptIfRecipientDomainIs $Account.Domain)
        $conditions.Count -gt 0 -and $conditions -notcontains $false -and -not $excluded
    }

    $report = foreach ($entry in $rules) {
        $rule = $entry.Rule
        $hasTargets = @($rule.SentTo | Where-Object { $_ }).Count -gt 0 -or @($rule.SentToMemberOf | Where-Object { $_ }).Count -gt 0 -or @($rule.RecipientDomainIs | Where-Object { $_ }).Count -gt 0
        $scope = if (-not $rule) { 'Rule not found' } elseif ($hasTargets) { 'Specific recipients' } else { 'All recipients (no conditions)' }
        $uncovered = if ($rule -and $hasTargets) { @($priorityAccounts | Where-Object { -not (& $isCovered $rule $_) }) } else { $priorityAccounts }
        [pscustomobject]@{
            Component = $entry.Name
            State     = if ($rule) { $rule.State } else { 'Not found' }
            Scope     = $scope
            Covered   = "$($priorityAccounts.Count - $uncovered.Count) of $($priorityAccounts.Count)"
            Uncovered = @($uncovered | ForEach-Object { $_.Name })
            Pass      = $null -ne $rule -and $rule.State -eq 'Enabled' -and $hasTargets -and $priorityAccounts.Count -gt 0 -and $uncovered.Count -eq 0
        }
    }
    $testResult = @($report | Where-Object { -not $_.Pass }).Count -eq 0

    $passText = 'The Strict preset security policy is enabled and applies to every priority account.'
    $failText = 'The Strict preset security policy is missing or disabled, has no recipient condition, or does not apply to every priority account.'
    $notes = ''
    if ($priorityAccounts.Count -eq 0) {
        $notes += "`n`nNo users are tagged as priority accounts. Tag them with the **Priority account** user tag (CIS 2.4.1), then add them to the Strict preset security policy."
    }
    if (@($report | Where-Object { $_.Scope -eq 'All recipients (no conditions)' }).Count -gt 0) {
        $notes += "`n`nA rule with no recipient conditions applies to everyone, but the CIS 2.4.2 audit requires the rule to name the priority accounts. Add a group that contains the priority accounts as a recipient condition."
    }

    $resultMd = "| Component | Rule state | Recipients | Priority accounts covered | Result |`n"
    $resultMd += "| --- | --- | --- | --- | --- |`n"
    foreach ($row in $report) {
        $resultMd += "| $($row.Component) | $($row.State) | $($row.Scope) | $($row.Covered) | $(if ($row.Pass) { '✅ Pass' } else { '❌ Fail' }) |`n"
    }
    $missing = @($report | Where-Object { $_.Uncovered.Count -gt 0 -and $_.Scope -eq 'Specific recipients' })
    if ($missing.Count -gt 0) {
        $resultMd += "`n| Component | Priority accounts not covered |`n"
        $resultMd += "| --- | --- |`n"
        foreach ($row in $missing) {
            $resultMd += "| $($row.Component) | $($row.Uncovered -join ', ') |`n"
        }
    }

    if ($testResult) {
        $testResultMarkdown = "Well done. $passText`n`n%TestResult%"
    } else {
        $testResultMarkdown = "$failText$notes`n`n%TestResult%"
    }
    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $resultMd

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
