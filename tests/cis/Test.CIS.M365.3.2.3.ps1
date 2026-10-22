function Test-MtCisDlpPoliciesCopilot {
    <#
    .SYNOPSIS
        Checks that a data loss prevention policy for Microsoft 365 Copilot is enabled for all users.

    .DESCRIPTION
        Checks that at least one data loss prevention policy for the Copilot experiences location is turned on and applies to all users.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (3.2.3, L1)

    .EXAMPLE
        Test-MtCisDlpPoliciesCopilot

        Returns true if an enabled DLP policy applies to Microsoft 365 Copilot.

    .LINK
        https://maester.dev/docs/tests/CIS.M365.3.2.3
    #>
    [MaesterTest(
        Id = 'CIS.M365.3.2.3',
        Title = 'Ensure DLP policies are published for Copilot users',
        Product = 'purview',
        Feature = 'data-loss-prevention',
        Area = 'data-protection',
        ResourceType = 'Tenant',
        Severity = 'High',
        UserImpact = 'Low',
        ImplementationCost = 'Medium',
        Mitre = ('T1213.002', 'T1530'),
        Control = ('cis-m365:3.2.3', 'nist-800-53-r5:AC-4'),
        Service = 'SecurityCompliance',
        License = 'EXCHANGE_DLP',
        Author = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Getting data loss prevention policies...'
    $policies = @(Get-MtExo -Request DlpCompliancePolicy)
    $rules = @(Get-MtExo -Request DlpComplianceRule)

    $report = foreach ($policy in $policies) {
        # Locations is a JSON string; Learn names the Microsoft 365 Copilot location 470f2276-e011-4e9d-a6ec-20768be3a4b0.
        $locations = @($policy.Locations | Where-Object { $_ } | ForEach-Object { if ($_ -isnot [string]) { $_ } elseif (Test-Json -Json $_ -ErrorAction Ignore) { ConvertFrom-Json -InputObject $_ } })
        $copilotLocations = @($locations | Where-Object { $_.Location -match 'Copilot|470f2276-e011-4e9d-a6ec-20768be3a4b0' -or $_.Workload -match 'Copilot' -or $_.Name -match 'Copilot' -or $_.DisplayName -match 'Copilot' })
        $copilotScope = @($policy.MicrosoftCopilotLocation | Where-Object { $_ })
        $isCopilot = @($policy.EnforcementPlanes) -contains 'CopilotExperiences' -or $copilotScope.Count -gt 0 -or $copilotLocations.Count -gt 0 -or "$($policy.Workload)" -match 'Copilot'
        $otherLocations = @($locations | Where-Object { $_.Location -notmatch 'Copilot|470f2276-e011-4e9d-a6ec-20768be3a4b0' -and $_.Workload -notmatch 'Copilot' -and $_.Name -notmatch 'Copilot' -and $_.DisplayName -notmatch 'Copilot' })
        $canUseTopLevelScope = $otherLocations.Count -eq 0
        $hasCopilotScope = $copilotScope.Count -gt 0 -or $copilotLocations.Count -gt 0
        if ($hasCopilotScope) {
            $copilotInclusions = @($copilotScope + @($copilotLocations | ForEach-Object { $_.Inclusions }) | Where-Object { $_ })
            $copilotExclusions = @($copilotLocations | ForEach-Object { $_.Exclusions } | Where-Object { $_ })
            if ($copilotInclusions.Count -gt 0) {
                $locationInclusions = $copilotInclusions
            } elseif ($canUseTopLevelScope) {
                $locationInclusions = @($policy.LocationInclusions | Where-Object { $_ })
            } else {
                $locationInclusions = @()
            }
            if ($copilotExclusions.Count -gt 0) {
                $locationExclusions = $copilotExclusions
            } elseif ($canUseTopLevelScope) {
                $locationExclusions = @($policy.LocationExclusions | Where-Object { $_ })
            } else {
                $locationExclusions = @()
            }
        } elseif ($canUseTopLevelScope) {
            $locationInclusions = @($policy.LocationInclusions | Where-Object { $_ })
            $locationExclusions = @($policy.LocationExclusions | Where-Object { $_ })
        } else {
            $locationInclusions = @()
            $locationExclusions = @()
        }
        $includesAll = @($locationInclusions | ForEach-Object { $_.ImmutableIdentity ?? $_.Identity ?? $_.Name ?? $_.DisplayName ?? $_ }) -contains 'All'
        $unitScoped = @($policy.PolicyRBACScopes | Where-Object { $_ }).Count -gt 0
        $policyRules = @($rules | Where-Object { $_.ParentPolicyName -eq $policy.Name })
        $activeRules = @($policyRules | Where-Object { -not $_.Disabled -and $_.Mode -eq 'Enforce' })
        $restrictingRules = @($activeRules | Where-Object {
                $properties = $_.PSObject.Properties
                $sensitiveCondition = $properties['ContentContainsSensitiveInformation']
                $advancedRule = $properties['AdvancedRule']
                $hasSensitiveCondition = ($sensitiveCondition -and @($sensitiveCondition.Value | Where-Object { $_ }).Count -gt 0) -or ($advancedRule -and "$($advancedRule.Value)" -match 'ContentContainsSensitiveInformation')
                $blockAccess = $properties['BlockAccess']
                $restrictAccess = $properties['RestrictAccess']
                $restrictWebGrounding = $properties['RestrictWebGrounding']
                $hasRestrictingAction = ($blockAccess -and $blockAccess.Value -eq $true) -or ($restrictAccess -and @($restrictAccess.Value | Where-Object { $_ -and "$_" -ne 'None' }).Count -gt 0) -or ($restrictWebGrounding -and $restrictWebGrounding.Value -eq $true)
                $hasSensitiveCondition -and $hasRestrictingAction
            })
        $hasQualifyingRule = $restrictingRules.Count -gt 0
        $qualifies = $isCopilot -and $policy.Mode -eq 'Enable' -and -not $policy.IsSimulationPolicy -and $includesAll -and -not $unitScoped -and $hasQualifyingRule
        [pscustomobject]@{
            Name = $policy.Name
            Mode = $policy.Mode
            Copilot = $isCopilot
            IncludesAll = $includesAll
            UnitScoped = $unitScoped
            Exclusions = $locationExclusions.Count
            Rules = $policyRules.Count
            RestrictingRules = $restrictingRules.Count
            Pass = $qualifies -and $locationExclusions.Count -eq 0
            ReviewRequired = $qualifies -and $locationExclusions.Count -gt 0
        }
    }
    $passingPolicy = @($report | Where-Object { $_.Pass }).Count -ge 1
    $reviewRequired = -not $passingPolicy -and @($report | Where-Object { $_.ReviewRequired }).Count -gt 0
    $testResult = $passingPolicy -or $reviewRequired

    $passText = 'An enabled data loss prevention policy covers all users for Microsoft 365 Copilot and has an enforcing rule for sensitive data.'
    $reviewText = 'A qualifying Microsoft 365 Copilot data loss prevention policy has location exclusions that need manual review.'
    $failText = 'No enabled Microsoft 365 Copilot data loss prevention policy covers all users with an enforcing rule for sensitive data.'

    $resultMd = "| Policy | Mode | Copilot location | Includes All | Unit scoped | Exclusions | Rules | Restricting rules | Result |`n"
    $resultMd += "| --- | --- | --- | --- | --- | --- | --- | --- | --- |`n"
    foreach ($row in $report) {
        $result = if ($row.Pass) { '✅ Pass' } elseif ($row.ReviewRequired) { 'Review' } else { '❌ Fail' }
        $resultMd += "| $($row.Name) | $($row.Mode) | $($row.Copilot) | $($row.IncludesAll) | $($row.UnitScoped) | $($row.Exclusions) | $($row.Rules) | $($row.RestrictingRules) | $result |`n"
    }

    if ($passingPolicy) {
        $testResultMarkdown = "Well done. $passText`n`n%TestResult%"
    } elseif ($reviewRequired) {
        $testResultMarkdown = "$reviewText`n`n%TestResult%"
    } else {
        $testResultMarkdown = "$failText`n`n%TestResult%"
    }
    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $resultMd

    if ($reviewRequired) {
        Add-MtTestResultDetail -Result $testResultMarkdown -Investigate
    } else {
        Add-MtTestResultDetail -Result $testResultMarkdown
    }
    return $testResult
}
