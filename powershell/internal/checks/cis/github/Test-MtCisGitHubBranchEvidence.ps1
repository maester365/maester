function Test-MtCisGitHubBranchEvidence {
    <#
    .SYNOPSIS
    Internal: Evaluates one CIS GitHub classic-configuration audit over its explicit population.
    .DESCRIPTION
    Evidence dependencies are lazy. Error takes precedence over Failed, then indeterminate. Rulesets receive no equivalence credit.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)] [ValidateSet('1.1.4', '1.1.7', '1.1.9', '1.1.10', '1.1.11', '1.1.12', '1.1.14', '1.1.16', '1.1.17', '1.1.20')] [string] $Control)
    $rows = [System.Collections.Generic.List[object]]::new()
    $issues = [System.Collections.Generic.List[string]]::new()
    $kind = if ($Control -eq '1.1.12') { 'Signatures' } elseif ($Control -in '1.1.9', '1.1.10') { 'StatusChecks' } else { 'Protection' }
    $knownRuleTypes = @('creation', 'update', 'deletion', 'required_linear_history', 'merge_queue', 'required_deployments', 'required_signatures', 'pull_request', 'required_status_checks', 'non_fast_forward', 'commit_message_pattern', 'commit_author_email_pattern', 'committer_email_pattern', 'branch_name_pattern', 'tag_name_pattern', 'workflows', 'code_scanning', 'code_quality', 'code_coverage', 'copilot_code_review', 'license_compliance_scanning', 'file_path_restriction', 'max_file_path_length', 'file_extension_restriction', 'max_file_size')
    $candidateTypes = switch ($Control) {
        { $_ -in '1.1.4', '1.1.7', '1.1.11' } { @('pull_request', 'update') }
        { $_ -in '1.1.9', '1.1.10' } { @('required_status_checks', 'workflows', 'merge_queue', 'update') }
        '1.1.12' { @('required_signatures', 'update') }
        '1.1.16' { @('non_fast_forward', 'update') }
        '1.1.17' { @('deletion') }
        default { $knownRuleTypes }
    }
    try { $scope = Resolve-MtCisGitHubRepositoryScope -Control $Control } catch {
        $message = if ($_.Exception.Message -match '^(GitHubCisRepositoryScope|Every scope|Every excluded)') { $_.Exception.Message } else { 'Required repository inventory collection or parsing failed.' }
        return [pscustomobject]@{ Verdict = 'Error'; Detail = $message }
    }
    foreach ($issue in $scope.Issues) { $issues.Add($issue) }
    :repositories foreach ($entry in $scope.Repositories) {
        $repository = $entry.Repository
        $branches = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
        foreach ($branch in $entry.Branches) { $null = $branches.Add($branch) }
        try {
            if ($Control -eq '1.1.12') {
                $population = Get-MtCisGitHubBranchEvidence -Repository $repository -Kind Branches
                if ($population.State -ne 'Available') { $issues.Add('Existing-branch enumeration contains incomplete or unusable evidence.') }
                foreach ($branch in $population.Data) {
                    if (($null -eq $branch -or $branch.GetType() -ne [System.Management.Automation.PSCustomObject]) -or $branch.name -isnot [string] -or [string]::IsNullOrWhiteSpace($branch.name)) { $issues.Add('A branch item has no usable identity.'); continue }
                    if (-not $branches.Add($branch.name)) { $issues.Add('Existing-branch enumeration contains a duplicate name.') }
                }
                if ($branches.Count -eq 0) { $issues.Add('An in-use repository returned no existing branches; applicability is unresolved.') }
            }
            if ($Control -eq '1.1.20') {
                $current = Get-MtCisGitHubBranchEvidence -Repository $repository -Kind Repository
                if ($current.State -ne 'Available' -or ($current.Data.id -isnot [int] -and $current.Data.id -isnot [long]) -or $current.Data.id -ne $repository.id -or $current.Data.default_branch -isnot [string] -or [string]::IsNullOrWhiteSpace($current.Data.default_branch)) {
                    $issues.Add('The actual default branch could not be established.')
                } else { $null = $branches.Add($current.Data.default_branch) }
            }
        } catch {
            $rows.Add([pscustomobject]@{ Repository = $repository.full_name; Branch = '(population)'; Verdict = 'Error'; Reason = 'Required population request failed.'; StartedUtc = $null; CompletedUtc = $null })
            if ($_.Exception.Data['GitHubRateLimit']) { $issues.Add('Collection stopped for rate limiting; remaining objects were not assessed.'); break repositories }
            continue
        }
        foreach ($branch in $branches) {
            $verdict = 'Indeterminate'
            $reason = 'Required policy evidence is absent or unusable.'
            $evidence = $null
            $rateLimited = $false
            try {
                $evidence = Get-MtCisGitHubBranchEvidence -Repository $repository -Branch $branch -Kind $kind
                $policy = $evidence.Data
                $conforming = $null
                if ($evidence.State -eq 'Available') {
                    switch ($Control) {
                        '1.1.4' { if (($null -ne $policy.required_pull_request_reviews -and $policy.required_pull_request_reviews.GetType() -eq [System.Management.Automation.PSCustomObject]) -and $policy.required_pull_request_reviews.dismiss_stale_reviews -is [bool]) { $conforming = $policy.required_pull_request_reviews.dismiss_stale_reviews; $reason = "dismiss_stale_reviews=$conforming" } }
                        '1.1.7' { if (($null -ne $policy.required_pull_request_reviews -and $policy.required_pull_request_reviews.GetType() -eq [System.Management.Automation.PSCustomObject]) -and $policy.required_pull_request_reviews.require_code_owner_reviews -is [bool]) { $conforming = $policy.required_pull_request_reviews.require_code_owner_reviews; $reason = "require_code_owner_reviews=$conforming" } }
                        { $_ -in '1.1.9', '1.1.10' } {
                            $usable = $policy.contexts -is [array] -and $policy.checks -is [array]
                            foreach ($context in $policy.contexts) { if ($context -isnot [string] -or [string]::IsNullOrWhiteSpace($context)) { $usable = $false } }
                            foreach ($check in $policy.checks) {
                                if (($null -eq $check -or $check.GetType() -ne [System.Management.Automation.PSCustomObject]) -or $check.context -isnot [string] -or [string]::IsNullOrWhiteSpace($check.context) -or -not (Test-MtGitHubObjectProperty -InputObject $check -PropertyName app_id) -or ($null -ne $check.app_id -and $check.app_id -isnot [int] -and $check.app_id -isnot [long])) { $usable = $false }
                            }
                            if ($Control -eq '1.1.10' -and $policy.strict -isnot [bool]) { $usable = $false }
                            if ($usable) {
                                $conforming = ($policy.contexts.Count + $policy.checks.Count) -gt 0
                                if ($Control -eq '1.1.10') { $conforming = $conforming -and $policy.strict }
                                $reason = "Required contexts=$($policy.contexts.Count); checks=$($policy.checks.Count)"
                                if ($Control -eq '1.1.10') {
                                    $reason += "; strict=$($policy.strict)"
                                    if ($policy.strict -and $policy.contexts.Count -eq 0 -and $policy.checks.Count -eq 0) {
                                        $conforming = $null
                                        $reason += '; the required-check set is empty and freshness enforcement is not established.'
                                    }
                                }
                            }
                        }
                        '1.1.11' { if ($null -ne $policy.required_conversation_resolution -and $policy.required_conversation_resolution.GetType() -eq [System.Management.Automation.PSCustomObject] -and $policy.required_conversation_resolution.enabled -is [bool]) { $conforming = $policy.required_conversation_resolution.enabled; $reason = "required_conversation_resolution.enabled=$conforming" } }
                        '1.1.12' { if ($policy.enabled -is [bool]) { $conforming = $policy.enabled; $reason = "required_signatures.enabled=$conforming" } }
                        '1.1.14' { if ($null -ne $policy.enforce_admins -and $policy.enforce_admins.GetType() -eq [System.Management.Automation.PSCustomObject] -and $policy.enforce_admins.enabled -is [bool]) { $conforming = $policy.enforce_admins.enabled; $reason = "enforce_admins.enabled=$conforming" } }
                        '1.1.16' { if ($null -ne $policy.allow_force_pushes -and $policy.allow_force_pushes.GetType() -eq [System.Management.Automation.PSCustomObject] -and $policy.allow_force_pushes.enabled -is [bool]) { $conforming = -not $policy.allow_force_pushes.enabled; $reason = "allow_force_pushes.enabled=$($policy.allow_force_pushes.enabled)" } }
                        '1.1.17' { if ($null -ne $policy.allow_deletions -and $policy.allow_deletions.GetType() -eq [System.Management.Automation.PSCustomObject] -and $policy.allow_deletions.enabled -is [bool]) { $conforming = -not $policy.allow_deletions.enabled; $reason = "allow_deletions.enabled=$($policy.allow_deletions.enabled)" } }
                        '1.1.20' {
                            $expected = "$($__MtSession.GitHubConnection.ApiBaseUri)/repos/$([uri]::EscapeDataString($repository.owner.login))/$([uri]::EscapeDataString($repository.name))/branches/$([uri]::EscapeDataString($branch))/protection"
                            $actualUri = $null
                            $expectedUri = [uri]$expected
                            if ($policy.url -is [string] -and [uri]::TryCreate($policy.url, [UriKind]::Absolute, [ref]$actualUri) -and
                                $actualUri.Scheme -eq $expectedUri.Scheme -and $actualUri.Host -eq $expectedUri.Host -and $actualUri.Port -eq $expectedUri.Port -and
                                [uri]::UnescapeDataString($actualUri.AbsolutePath) -ceq [uri]::UnescapeDataString($expectedUri.AbsolutePath) -and
                                [string]::IsNullOrEmpty($actualUri.Query) -and [string]::IsNullOrEmpty($actualUri.Fragment) -and [string]::IsNullOrEmpty($actualUri.UserInfo)) {
                                $conforming = $true; $reason = 'An applicable classic branch protection object was returned.'
                            }
                        }
                    }
                }
                if ($null -ne $conforming -and $conforming) {
                    $verdict = 'Passed'
                } elseif ($null -ne $conforming -or $evidence.State -eq 'NotFoundOrNotVisible') {
                    $absent = $false
                    if ($evidence.State -eq 'NotFoundOrNotVisible') {
                        $state = Get-MtCisGitHubBranchEvidence -Repository $repository -Branch $branch -Kind Branch
                        if ($state.State -eq 'Available' -and $state.Data.name -ceq $branch -and $state.Data.protected -is [bool] -and -not $state.Data.protected) { $absent = $true }
                        else { $reason = 'HTTP 404 is ambiguous or protection may be supplied by rulesets.' }
                    }
                    if ($absent) { $verdict = 'Failed'; $reason = 'An accessible existing branch is unprotected.' }
                    elseif ($null -ne $conforming) {
                        $rules = Get-MtCisGitHubBranchEvidence -Repository $repository -Branch $branch -Kind Rules
                        $potential = $rules.State -ne 'Available'
                        foreach ($rule in $rules.Data) {
                            if ($rule.type -isnot [string] -or $rule.type -cnotin $knownRuleTypes -or $rule.type -cin $candidateTypes) { $potential = $true }
                        }
                        if ($potential) { $reason += '; alternative ruleset enforcement is unresolved.' }
                        else { $verdict = 'Failed' }
                    }
                }
            } catch {
                $verdict = 'Error'; $reason = 'A required GitHub evidence request or JSON parse failed.'
                $rateLimited = $null -ne $_.Exception.Data['GitHubRateLimit']
            }
            $rows.Add([pscustomobject]@{ Repository = $repository.full_name; Branch = $branch; Verdict = $verdict; Reason = $reason; StartedUtc = $evidence.StartedUtc; CompletedUtc = $evidence.CompletedUtc })
            if ($rateLimited) { $issues.Add('Collection stopped for rate limiting; remaining objects were not assessed.'); break repositories }
        }
    }
    $verdict = if (@($rows | Where-Object Verdict -EQ 'Error').Count) { 'Error' }
    elseif (@($rows | Where-Object Verdict -EQ 'Failed').Count) { 'Failed' }
    elseif ($issues.Count -gt 0 -or @($rows | Where-Object Verdict -EQ 'Indeterminate').Count) { 'Indeterminate' }
    elseif ($rows.Count -eq 0) { 'NotApplicable' } else { 'Passed' }
    $summary = switch ($verdict) {
        Passed { 'Well done. The CIS configuration audit is satisfied for the complete declared applicable population.' }
        Failed { 'Correct the nonconforming branch settings listed below. Any coverage gaps remain unresolved.' }
        Error { 'A required evidence operation failed. Retained findings do not establish a complete assessment.' }
        NotApplicable { 'No applicable repositories remain after complete applicability reconciliation.' }
        default { 'Indeterminate: complete usable evidence for this configuration audit is unavailable.' }
    }
    $target = [System.Net.WebUtility]::HtmlEncode([string]$__MtSession.GitHubConnection.Organization).Replace('|', '&#124;').Replace('`', '&#96;') -replace '[\r\n]', ' '
    if ($target.Length -gt 160) { $target = $target.Substring(0, 160) }
    $detail = "$summary`n`nCIS.GH.$Control; organization ``$target`` at ``$($__MtSession.GitHubConnection.ApiBaseUri)``. Excluded repositories: $($scope.ExcludedCount).`n`nRepository inventory observed UTC: $($scope.StartedUtc) through $($scope.CompletedUtc).`n`n| Repository | Branch | Finding | Evidence | UTC interval |`n| --- | --- | --- | --- | --- |`n"
    # Encode untrusted identifiers and cap presentation without dropping any finding from evaluation.
    $rank = @{ Error = 0; Failed = 1; Indeterminate = 2; Passed = 3 }
    foreach ($row in @($rows | Sort-Object { $rank[$_.Verdict] } | Select-Object -First 100)) {
        $repoText = [System.Net.WebUtility]::HtmlEncode([string]$row.Repository).Replace('|', '&#124;').Replace('`', '&#96;').Replace("`n", ' ').Replace("`r", ' ')
        $branchText = [System.Net.WebUtility]::HtmlEncode([string]$row.Branch).Replace('|', '&#124;').Replace('`', '&#96;').Replace("`n", ' ').Replace("`r", ' ')
        if ($repoText.Length -gt 160) { $repoText = $repoText.Substring(0, 160) }
        if ($branchText.Length -gt 160) { $branchText = $branchText.Substring(0, 160) }
        $detail += "| $repoText | $branchText | $($row.Verdict) | $($row.Reason) | $($row.StartedUtc) - $($row.CompletedUtc) |`n"
    }
    foreach ($state in 'Passed', 'Failed', 'Indeterminate', 'Error') { $detail += "`n$state findings: $(@($rows | Where-Object Verdict -EQ $state).Count)." }
    $detail += "`nEvaluated branch findings: $($rows.Count); displayed: $([Math]::Min(100, $rows.Count)). This is the named configuration audit, not proof of historical merges or enforcement against every actor. Bypass lists are not required to be empty.`n"
    foreach ($exclusion in @($scope.Exclusions | Select-Object -First 20)) {
        $exclusionText = [System.Net.WebUtility]::HtmlEncode("$($exclusion.Repository): $($exclusion.Reason)").Replace('|', '&#124;').Replace('`', '&#96;') -replace '[\r\n]', ' '
        if ($exclusionText.Length -gt 300) { $exclusionText = $exclusionText.Substring(0, 300) }
        $detail += "`nExcluded by applicability declaration: $exclusionText`n"
    }
    if ($issues.Count) { $detail += "`nCoverage: " + (($issues | Select-Object -Unique | Select-Object -First 20) -join ' ') }
    return [pscustomobject]@{ Verdict = $verdict; Detail = $detail }
}
