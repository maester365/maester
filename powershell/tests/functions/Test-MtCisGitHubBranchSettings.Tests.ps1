BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force
    function Get-CisBranchFixtureConfig {
        param([string[]] $Main = @('main'), [object[]] $Entries)
        if (-not $PSBoundParameters.ContainsKey('Entries')) { $Entries = @(@{ Id = 101; InUse = $true; MainBranches = $Main; LongStandingBranches = @() }) }
        @{ GlobalSettings = @{ GitHubCisRepositoryScope = @{ Organization = 'fixture-org'; Complete = $true; Repositories = $Entries } } }
    }
}

Describe 'CIS GitHub branch audits through production evidence and native results' {
    BeforeEach {
        $script:repoBody = '[{"id":101,"name":"repo","full_name":"fixture-org/repo","owner":{"login":"fixture-org"},"visibility":"private","archived":false,"disabled":false}]'
        $script:branchBody = '[{"name":"main","protected":true}]'
        $script:policyBody = '{"url":"https://api.github.com/repos/fixture-org/repo/branches/main/protection","required_pull_request_reviews":{"dismiss_stale_reviews":true,"require_code_owner_reviews":true},"required_conversation_resolution":{"enabled":true},"enforce_admins":{"enabled":true},"allow_force_pushes":{"enabled":false},"allow_deletions":{"enabled":false}}'
        $script:statusBody = '{"url":"https://api.github.com/repos/fixture-org/repo/branches/main/protection/required_status_checks","strict":true,"contexts":["ci"],"contexts_url":"https://api.github.com/repos/fixture-org/repo/branches/main/protection/required_status_checks/contexts","checks":[{"context":"ci","app_id":null}]}'
        $script:signatureBody = '{"enabled":true}'
        $script:rulesBody = '[]'
        $script:defaultBody = '{"id":101,"default_branch":"main"}'
        $script:branchStateBody = '{"name":"main","protected":true}'
        $script:policyStatus = 200
        $script:otherPolicyBody = $null
        $script:otherStatus = 200
        $script:signatureStatus = 200
        $script:repoHeaders = @{}
        InModuleScope Maester {
            $__MtSession.GitHubConnection = [pscustomobject]@{ Connected = $true; Organization = 'fixture-org'; ApiBaseUri = 'https://api.github.com'; ApiVersion = '2022-11-28' }
            $__MtSession.GitHubAuthHeader = @{ 'X-GitHub-Api-Version' = '2022-11-28' }
            $__MtSession.GitHubCache = @{}
            $__MtSession.MaesterConfig = $null
        }
        Mock Invoke-WebRequest -ModuleName Maester {
            if ($Method -ne 'GET' -or $Uri -notlike 'https://api.github.com/*') { throw 'Unexpected fixture request.' }
            $path = ([uri]$Uri).AbsolutePath
            $headers = @{}
            $status = 200
            $body = switch -Regex ($path) {
                '^/orgs/fixture-org/repos$' { $headers = $script:repoHeaders; $script:repoBody; break }
                '^/repos/fixture-org/repo$' { $script:defaultBody; break }
                '^/repos/fixture-org/repo/branches$' { $script:branchBody; break }
                '/protection/required_status_checks$' { $script:statusBody; break }
                '/protection/required_signatures$' { $status = $script:signatureStatus; $script:signatureBody; break }
                '/branches/other/protection$' { $status = $script:otherStatus; $(if ($null -ne $script:otherPolicyBody) { $script:otherPolicyBody } else { $script:policyBody }); break }
                '/protection$' { $status = $script:policyStatus; $script:policyBody; break }
                '/rules/branches/' { $script:rulesBody; break }
                '^/repos/fixture-org/repo/branches/[^/]+$' { $script:branchStateBody; break }
                default { throw 'Unexpected fixture URI.' }
            }
            if ($status -ne 200) { throw [Microsoft.PowerShell.Commands.HttpResponseException]::new('Synthetic HTTP failure', [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]$status)) }
            [pscustomobject]@{ Content = $body; Headers = $headers }
        }
    }
    AfterEach { InModuleScope Maester { $__MtSession.GitHubConnection = $null; $__MtSession.GitHubAuthHeader = $null; $__MtSession.GitHubCache = @{}; $__MtSession.MaesterConfig = $null } }

    It 'Passes the full named configuration audit <Id> without unrelated reads' -ForEach @(
        foreach ($id in '1.1.4','1.1.7','1.1.9','1.1.10','1.1.11','1.1.12','1.1.14','1.1.16','1.1.17','1.1.20') { @{ Id = "CIS.GH.$id" } }
    ) {
        $row = @(Invoke-MtTest -Id $Id -Config (Get-CisBranchFixtureConfig))
        $row.Count | Should -Be 1
        $row[0].Result | Should -Be 'Passed'
        $row[0].ResultDetail.TestResult | Should -Match 'complete declared applicable population'
        Should -Invoke Invoke-WebRequest -ModuleName Maester -Exactly -Times 0 -ParameterFilter { $Uri -match '/rules/' }
        if ($Id -ne 'CIS.GH.1.1.12') { Should -Invoke Invoke-WebRequest -ModuleName Maester -Exactly -Times 0 -ParameterFilter { $Uri -match '/required_signatures$|/branches\?per_page=' } }
    }
    It 'Fails a documented nonconforming classic value for <Id>' -ForEach @(
        @{ Id='CIS.GH.1.1.4'; Parent='required_pull_request_reviews'; Field='dismiss_stale_reviews'; Value=$false }
        @{ Id='CIS.GH.1.1.7'; Parent='required_pull_request_reviews'; Field='require_code_owner_reviews'; Value=$false }
        @{ Id='CIS.GH.1.1.11'; Parent='required_conversation_resolution'; Field='enabled'; Value=$false }
        @{ Id='CIS.GH.1.1.14'; Parent='enforce_admins'; Field='enabled'; Value=$false }
        @{ Id='CIS.GH.1.1.16'; Parent='allow_force_pushes'; Field='enabled'; Value=$true }
        @{ Id='CIS.GH.1.1.17'; Parent='allow_deletions'; Field='enabled'; Value=$true }
    ) {
        $policy = $script:policyBody | ConvertFrom-Json
        $policy.$Parent.$Field = $Value
        $script:policyBody = $policy | ConvertTo-Json -Depth 8 -Compress
        (Invoke-MtTest -Id $Id -Config (Get-CisBranchFixtureConfig)).Result | Should -Be 'Failed'
    }
    It 'Keeps absent/null/defensive wrong-type parent or flag indeterminate for <Id>/<Json>' -ForEach @(
        foreach ($case in @(
            @{Id='CIS.GH.1.1.4';Parent='required_pull_request_reviews';Field='dismiss_stale_reviews'},
            @{Id='CIS.GH.1.1.7';Parent='required_pull_request_reviews';Field='require_code_owner_reviews'},
            @{Id='CIS.GH.1.1.11';Parent='required_conversation_resolution';Field='enabled'},
            @{Id='CIS.GH.1.1.14';Parent='enforce_admins';Field='enabled'},
            @{Id='CIS.GH.1.1.16';Parent='allow_force_pushes';Field='enabled'},
            @{Id='CIS.GH.1.1.17';Parent='allow_deletions';Field='enabled'}
        )) {
            foreach ($json in 'null','"true"','1','[]','[{}]') { @{Id=$case.Id;Parent=$case.Parent;Field=$case.Field;Json=$json} }
        }
    ) {
        $script:policyBody = '{"' + $Parent + '":{"' + $Field + '":' + $Json + '}}'
        (Invoke-MtTest -Id $Id -Config (Get-CisBranchFixtureConfig)).Result | Should -Be 'Skipped'
    }
    It 'Rejects defensive singleton-array policy parents for <Parent>/<Id>' -ForEach @(
        @{Id='CIS.GH.1.1.4';Parent='required_pull_request_reviews';Fields='"dismiss_stale_reviews":true'}
        @{Id='CIS.GH.1.1.7';Parent='required_pull_request_reviews';Fields='"require_code_owner_reviews":true'}
        @{Id='CIS.GH.1.1.11';Parent='required_conversation_resolution';Fields='"enabled":true'}
        @{Id='CIS.GH.1.1.14';Parent='enforce_admins';Fields='"enabled":true'}
        @{Id='CIS.GH.1.1.16';Parent='allow_force_pushes';Fields='"enabled":false'}
        @{Id='CIS.GH.1.1.17';Parent='allow_deletions';Fields='"enabled":false'}
    ) {
        $script:policyBody = '{"' + $Parent + '":[{' + $Fields + '}]}'
        (Invoke-MtTest -Id $Id -Config (Get-CisBranchFixtureConfig)).Result | Should -Be 'Skipped'
    }
    It 'Keeps the predefined-check requirement distinct from unresolved empty-set freshness' {
        $policy = $script:statusBody | ConvertFrom-Json
        $policy.contexts = @()
        $policy.checks = @()
        $script:statusBody = $policy | ConvertTo-Json -Depth 8 -Compress
        (Invoke-MtTest -Id CIS.GH.1.1.9 -Config (Get-CisBranchFixtureConfig)).Result | Should -Be 'Failed'
        $row = Invoke-MtTest -Id CIS.GH.1.1.10 -Config (Get-CisBranchFixtureConfig)
        $row.Result | Should -Be 'Skipped'
        $row.ReasonCode | Should -Be 'TestSkipped'
        $row.ReasonDetail | Should -Match 'strict=True.*empty.*freshness enforcement.*not established'
        $row.ResultDetail.TestResult | Should -Match 'Indeterminate findings: 1'
        Should -Invoke Invoke-WebRequest -ModuleName Maester -Exactly -Times 1 -ParameterFilter { $Uri -match '/protection/required_status_checks$' -and $Headers['X-GitHub-Api-Version'] -eq '2026-03-10' }
        Should -Invoke Invoke-WebRequest -ModuleName Maester -Exactly -Times 1 -ParameterFilter { ([uri]$Uri).AbsolutePath -eq '/repos/fixture-org/repo/rules/branches/main' }
    }
    It 'Preserves <Expected> precedence over an indeterminate empty-set freshness branch' -ForEach @(
        @{ Expected = 'Failed'; RequestError = $false }
        @{ Expected = 'Error'; RequestError = $true }
    ) {
        $policy = $script:statusBody | ConvertFrom-Json
        $policy.contexts = @()
        $policy.checks = @()
        $script:statusBody = $policy | ConvertTo-Json -Depth 8 -Compress
        $script:otherStatusBody = $script:statusBody.Replace('/main/', '/other/').Replace('"strict":true', '"strict":false')
        $script:statusRequestError = $RequestError
        Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/branches/other/protection/required_status_checks$' } {
            if ($script:statusRequestError) { throw [Microsoft.PowerShell.Commands.HttpResponseException]::new('Synthetic forbidden policy', [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]403)) }
            [pscustomobject]@{ Content = $script:otherStatusBody; Headers = @{} }
        }
        $row = Invoke-MtTest -Id CIS.GH.1.1.10 -Config (Get-CisBranchFixtureConfig -Main @('main', 'other'))
        $row.Result | Should -Be $Expected
        $row.ResultDetail.TestResult | Should -Match 'Indeterminate findings: 1'
        $row.ResultDetail.TestResult | Should -Match ($Expected + ' findings: 1')
        $row.ResultDetail.TestResult | Should -Match 'freshness enforcement.*not established'
    }
    It 'Requires strict freshness only for 1.1.10' {
        $script:statusBody = '{"strict":false,"contexts":["ci"],"checks":[]}'
        (Invoke-MtTest -Id CIS.GH.1.1.9 -Config (Get-CisBranchFixtureConfig)).Result | Should -Be 'Passed'
        (Invoke-MtTest -Id CIS.GH.1.1.10 -Config (Get-CisBranchFixtureConfig)).Result | Should -Be 'Failed'
    }
    It 'Rejects unusable status policy <Body>' -ForEach @(
        @{Body='{"strict":true,"contexts":null,"checks":[]}'}
        @{Body='{"strict":true,"contexts":[],"checks":[{"context":"ci"}]}'}
        @{Body='{"strict":true,"contexts":[],"checks":[{"context":"ci","app_id":"1"}]}'}
        @{Body='{"strict":true,"contexts":[null],"checks":[]}'}
        @{Body='{"strict":"true","contexts":["ci"],"checks":[]}'}
    ) {
        $script:statusBody = $Body
        (Invoke-MtTest -Id CIS.GH.1.1.10 -Config (Get-CisBranchFixtureConfig)).Result | Should -Be 'Skipped'
    }
    It 'Evaluates every existing branch, including a later page with an unsigned branch' {
        $script:branchBody = '[{"name":"main","protected":true}]'
        Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -eq 'https://api.github.com/repos/fixture-org/repo/branches?per_page=100' } { [pscustomobject]@{ Content=$script:branchBody;Headers=@{Link='<https://api.github.com/repos/fixture-org/repo/branches?page=2>; rel="next"'} } }
        Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/branches\?page=2$' } { [pscustomobject]@{Content='[{"name":"feature/a","protected":true}]';Headers=@{}} }
        Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/feature%2Fa/protection/required_signatures$' } { [pscustomobject]@{Content='{"enabled":false}';Headers=@{}} }
        $config=Get-CisBranchFixtureConfig
        $config.GlobalSettings.GitHubCisRepositoryScope.Repositories[0].Remove('MainBranches')
        $config.GlobalSettings.GitHubCisRepositoryScope.Repositories[0].Remove('LongStandingBranches')
        (Invoke-MtTest -Id CIS.GH.1.1.12 -Config $config).Result | Should -Be 'Failed'
        Should -Invoke Invoke-WebRequest -ModuleName Maester -Exactly -Times 1 -ParameterFilter { $Uri -match '/feature%2Fa/protection/required_signatures$' }
    }
    It 'Never turns defensive unusable branch populations <Body> into complete success' -ForEach @(
        @{Body='[null,{"name":"main"}]'},@{Body='[null]'},@{Body='[]'},@{Body='null'},@{Body=''},@{Body='[[{"name":"main"}]]'},@{Body='[{"name":null}]'},@{Body='[{"name":"main"},{"name":"main"}]'}
    ) {
        $script:branchBody=$Body
        (Invoke-MtTest -Id CIS.GH.1.1.12 -Config (Get-CisBranchFixtureConfig)).Result | Should -Be 'Skipped'
    }
    It 'Keeps a real violation alongside missing evidence Failed with coverage disclosure' {
        $script:policyBody=$script:policyBody.Replace('"dismiss_stale_reviews":true','"dismiss_stale_reviews":false')
        $script:otherPolicyBody='{}'
        $row=Invoke-MtTest -Id CIS.GH.1.1.4 -Config (Get-CisBranchFixtureConfig -Main @('main','other'))
        $row.Result | Should -Be 'Failed'
        $row.ResultDetail.TestResult | Should -Match 'Indeterminate'
    }
    It 'Gives required collection Error precedence while retaining confirmed violation detail' {
        $script:policyBody=$script:policyBody.Replace('"dismiss_stale_reviews":true','"dismiss_stale_reviews":false')
        $script:otherStatus=403
        $row=Invoke-MtTest -Id CIS.GH.1.1.4 -Config (Get-CisBranchFixtureConfig -Main @('main','other'))
        $row.Result | Should -Be 'Error'
        $row.ResultDetail.TestResult | Should -Match 'Failed'
    }
    It 'Does not let signature-specific permission failure invalidate independent classic evidence' {
        $script:signatureStatus=403
        $rows=@(Invoke-MtTest -Id CIS.GH.1.1.4,CIS.GH.1.1.12 -Config (Get-CisBranchFixtureConfig))
        ($rows|Where-Object Id -EQ CIS.GH.1.1.4).Result | Should -Be 'Passed'
        ($rows|Where-Object Id -EQ CIS.GH.1.1.12).Result | Should -Be 'Error'
    }
    It 'Does not require unrelated classifications for the all-branch assessment' {
        $config=Get-CisBranchFixtureConfig
        $config.GlobalSettings.GitHubCisRepositoryScope.Repositories[0].MainBranches='irrelevant malformed classification'
        $config.GlobalSettings.GitHubCisRepositoryScope.Repositories[0].LongStandingBranches=$false
        (Invoke-MtTest -Id CIS.GH.1.1.12 -Config $config).Result | Should -Be 'Passed'
    }
    It 'Requires long-standing declarations only for 1.1.16' {
        $config=Get-CisBranchFixtureConfig
        $config.GlobalSettings.GitHubCisRepositoryScope.Repositories[0].Remove('LongStandingBranches')
        (Invoke-MtTest -Id CIS.GH.1.1.4 -Config $config).Result | Should -Be 'Passed'
        (Invoke-MtTest -Id CIS.GH.1.1.16 -Config $config).Result | Should -Be 'Skipped'
    }
    It 'Does not reject nonempty bypass context or read additional rulesets for conforming classic settings' {
        $policy=$script:policyBody|ConvertFrom-Json
        $policy.required_pull_request_reviews|Add-Member bypass_pull_request_allowances ([pscustomobject]@{users=@([pscustomobject]@{login='fixture-user'})})
        $script:policyBody=$policy|ConvertTo-Json -Depth 10 -Compress
        Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '/rules/' } { throw 'An unnecessary rules request was made.' }
        (Invoke-MtTest -Id CIS.GH.1.1.14 -Config (Get-CisBranchFixtureConfig)).Result | Should -Be 'Passed'
        (Invoke-MtTest -Id CIS.GH.1.1.4 -Config (Get-CisBranchFixtureConfig)).Result | Should -Be 'Passed'
        Should -Invoke Invoke-WebRequest -ModuleName Maester -Exactly -Times 0 -ParameterFilter { $Uri -match '/rules/' }
    }
    It 'Does not credit potentially compensating or unrecognized rules <Type>' -ForEach @(
        @{Type='pull_request'},@{Type='PULL_REQUEST'},@{Type='future_rule'}
    ) {
        $script:policyBody=$script:policyBody.Replace('"dismiss_stale_reviews":true','"dismiss_stale_reviews":false')
        $script:rulesBody='[{"type":"'+$Type+'","ruleset_source_type":"Enterprise","ruleset_id":1}]'
        (Invoke-MtTest -Id CIS.GH.1.1.4 -Config (Get-CisBranchFixtureConfig)).Result | Should -Be 'Skipped'
    }
    It 'Does not credit an unrelated active rule as review protection' {
        $script:policyBody=$script:policyBody.Replace('"dismiss_stale_reviews":true','"dismiss_stale_reviews":false')
        $script:rulesBody='[{"type":"required_signatures"}]'
        (Invoke-MtTest -Id CIS.GH.1.1.4 -Config (Get-CisBranchFixtureConfig)).Result | Should -Be 'Failed'
    }
    It 'Contextualizes policy 404 as ambiguous until an accessible branch proves absence' {
        $script:policyStatus=404
        (Invoke-MtTest -Id CIS.GH.1.1.4 -Config (Get-CisBranchFixtureConfig)).Result | Should -Be 'Skipped'
        InModuleScope Maester {$__MtSession.GitHubCache=@{}}
        $script:branchStateBody='{"name":"main","protected":false}'
        (Invoke-MtTest -Id CIS.GH.1.1.4 -Config (Get-CisBranchFixtureConfig)).Result | Should -Be 'Failed'
    }
    It 'Retains archived/disabled repositories and all <Visibility> visibility classes' -ForEach @(@{Visibility='public'},@{Visibility='internal'},@{Visibility='private'}) {
        $script:repoBody=$script:repoBody.Replace('"private"','"'+$Visibility+'"').Replace('"archived":false','"archived":true').Replace('"disabled":false','"disabled":true')
        (Invoke-MtTest -Id CIS.GH.1.1.4 -Config (Get-CisBranchFixtureConfig)).Result | Should -Be 'Passed'
        Should -Invoke Invoke-WebRequest -ModuleName Maester -Exactly -Times 1 -ParameterFilter {$Uri -match '/repos\?type=all&per_page=100$'}
    }
    It 'Does not hide null or inaccessible repository inventory members' {
        $script:repoBody=$script:repoBody.Replace('[{','[null,{')
        (Invoke-MtTest -Id CIS.GH.1.1.4 -Config (Get-CisBranchFixtureConfig)).Result | Should -Be 'Skipped'
    }
    It 'Rejects unusable or duplicate repository identities <Body>' -ForEach @(
        @{Body='[{"id":"101","name":"repo","full_name":"fixture-org/repo","owner":{"login":"fixture-org"}}]'}
        @{Body='[{"id":101,"name":"repo","full_name":"fixture-org/repo","owner":[{"login":"fixture-org"}]}]'}
        @{Body='[{"id":101,"name":"repo","full_name":"fixture-org/repo","owner":{"login":"fixture-org"}},{"id":101,"name":"repo","full_name":"fixture-org/repo","owner":{"login":"fixture-org"}}]'}
    ) {
        $script:repoBody=$Body
        (Invoke-MtTest -Id CIS.GH.1.1.4 -Config (Get-CisBranchFixtureConfig)).Result | Should -Be 'Skipped'
    }
    It 'Requires typed default-branch correlation and actual protection for the default branch' {
        $script:defaultBody='{"id":"101","default_branch":"main"}'
        (Invoke-MtTest -Id CIS.GH.1.1.20 -Config (Get-CisBranchFixtureConfig)).Result | Should -Be 'Skipped'
    }
    It 'Uses NotApplicable only for complete justified exclusions and preserves their detail' {
        $row=Invoke-MtTest -Id CIS.GH.1.1.4 -Config (Get-CisBranchFixtureConfig -Entries @(@{Id=101;InUse=$false;ExclusionReason='Fixture repository no longer used'}))
        $row.Result | Should -Be 'Skipped'
        $row.ReasonCode | Should -Be 'NotApplicable'
        $row.ResultDetail.TestResult | Should -Match 'Fixture repository no longer used'
    }
    It 'Does not treat an unexplained empty inventory as NotApplicable' {
        $script:repoBody='[]'
        $row=Invoke-MtTest -Id CIS.GH.1.1.4 -Config (Get-CisBranchFixtureConfig -Entries @())
        $row.Result | Should -Be 'Skipped'
        $row.ReasonCode | Should -Not -Be 'NotApplicable'
    }
    It 'Re-resolves scope between invocations without reusing an earlier verdict' {
        (Invoke-MtTest -Id CIS.GH.1.1.4 -Config (Get-CisBranchFixtureConfig)).Result | Should -Be 'Passed'
        $script:otherPolicyBody='{}'
        (Invoke-MtTest -Id CIS.GH.1.1.4 -Config (Get-CisBranchFixtureConfig -Main @('other'))).Result | Should -Be 'Skipped'
        InModuleScope Maester {$__MtSession.MaesterConfig} | Should -BeNullOrEmpty
        Should -Invoke Invoke-WebRequest -ModuleName Maester -Exactly -Times 1 -ParameterFilter {$Uri -match '/branches/other/protection$'}
    }
    It 'Honors real layered configuration replacement including empty branch arrays' {
        $file=Join-Path $TestDrive 'branch.json'
        Get-CisBranchFixtureConfig | ConvertTo-Json -Depth 12 | Set-Content $file
        $overlay=@{GlobalSettings=@{GitHubCisRepositoryScope=@{Repositories=@(@{Id=101;InUse=$true;MainBranches=@();LongStandingBranches=@()})}}}
        (Invoke-MtTest -Id CIS.GH.1.1.4 -Config @($file,$overlay)).Result | Should -Be 'Skipped'
    }
    It 'Rejects malformed Complete types through actual configuration resolution' {
        $config=Get-CisBranchFixtureConfig
        $config.GlobalSettings.GitHubCisRepositoryScope.Complete='true'
        (Invoke-MtTest -Id CIS.GH.1.1.4 -Config $config).Result | Should -Be 'Error'
    }
    It 'Rejects a singleton array supplied as the scope object' {
        $config=Get-CisBranchFixtureConfig
        $config.GlobalSettings.GitHubCisRepositoryScope=@($config.GlobalSettings.GitHubCisRepositoryScope)
        (Invoke-MtTest -Id CIS.GH.1.1.4 -Config $config).Result | Should -Be 'Error'
    }
    It 'Rejects unavailable and defensive invalid signature fields <Body>' -ForEach @(
        @{Body='{}'},@{Body='{"enabled":null}'},@{Body='{"enabled":"true"}'},@{Body='[{"enabled":true}]'}
    ) {
        $script:signatureBody=$Body
        (Invoke-MtTest -Id CIS.GH.1.1.12 -Config (Get-CisBranchFixtureConfig)).Result | Should -Be 'Skipped'
    }
    It 'Assesses the actual default branch when it differs from the classified main branch' {
        $script:defaultBody='{"id":101,"default_branch":"release"}'
        Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter {$Uri -match '/branches/release/protection$'} {
            throw [Microsoft.PowerShell.Commands.HttpResponseException]::new('Synthetic missing protection',[System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]404))
        }
        Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter {$Uri -match '/branches/release$'} { [pscustomobject]@{Content='{"name":"release","protected":false}';Headers=@{}} }
        (Invoke-MtTest -Id CIS.GH.1.1.20 -Config (Get-CisBranchFixtureConfig)).Result | Should -Be 'Failed'
        Should -Invoke Invoke-WebRequest -ModuleName Maester -Exactly -Times 1 -ParameterFilter {$Uri -match '/branches/release/protection$'}
    }
    It 'Reconciles every repository page including an explicitly excluded archived repository' {
        Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter {$Uri -eq 'https://api.github.com/orgs/fixture-org/repos?type=all&per_page=100'} {
            [pscustomobject]@{Content=$script:repoBody;Headers=@{Link='<https://api.github.com/orgs/fixture-org/repos?type=all&page=2>; rel="next"'}}
        }
        Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter {$Uri -match 'type=all&page=2$'} {
            [pscustomobject]@{Content='[{"id":102,"name":"old","full_name":"fixture-org/old","owner":{"login":"fixture-org"},"archived":true}]';Headers=@{}}
        }
        $config=Get-CisBranchFixtureConfig -Entries @(@{Id=101;InUse=$true;MainBranches=@('main')},@{Id=102;InUse=$false;ExclusionReason='Retired fixture repository'})
        (Invoke-MtTest -Id CIS.GH.1.1.4 -Config $config).Result | Should -Be 'Passed'
        Should -Invoke Invoke-WebRequest -ModuleName Maester -Exactly -Times 1 -ParameterFilter {$Uri -match 'type=all&page=2$'}
    }
    It 'Treats a required repository page error as Error rather than a complete visible-only pass' {
        Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter {$Uri -eq 'https://api.github.com/orgs/fixture-org/repos?type=all&per_page=100'} {
            [pscustomobject]@{Content=$script:repoBody;Headers=@{Link='<https://api.github.com/orgs/fixture-org/repos?type=all&page=2>; rel="next"'}}
        }
        Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter {$Uri -match 'type=all&page=2$'} {
            throw [Microsoft.PowerShell.Commands.HttpResponseException]::new('Synthetic forbidden page',[System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]403))
        }
        (Invoke-MtTest -Id CIS.GH.1.1.4 -Config (Get-CisBranchFixtureConfig)).Result | Should -Be 'Error'
    }
    It 'Honors the actual MAESTER_CONFIG resolution path' {
        $old=$env:MAESTER_CONFIG
        try {
            $file=Join-Path $TestDrive 'environment.json'
            Get-CisBranchFixtureConfig|ConvertTo-Json -Depth 12|Set-Content $file
            $env:MAESTER_CONFIG=$file
            (Invoke-MtTest -Id CIS.GH.1.1.4).Result | Should -Be 'Passed'
        } finally { $env:MAESTER_CONFIG=$old }
    }

    It 'Does not correlate protection for a differently cased branch name' {
        (Invoke-MtTest -Id CIS.GH.1.1.20 -Config (Get-CisBranchFixtureConfig -Main @('Main'))).Result | Should -Be 'Skipped'
    }
    It 'Preserves case-insensitive URI host semantics in protection correlation' {
        InModuleScope Maester {$__MtSession.GitHubConnection.ApiBaseUri='https://API.GITHUB.COM'}
        (Invoke-MtTest -Id CIS.GH.1.1.20 -Config (Get-CisBranchFixtureConfig)).Result | Should -Be 'Passed'
    }

    It 'Evaluates beyond the presentation limit and displays violating branches first' {
        $script:branchBody=@(0..100|ForEach-Object {@{name=('b{0:d3}' -f $_)}})|ConvertTo-Json -Compress
        Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter {$Uri -match '/branches/b100/protection/required_signatures$'} { [pscustomobject]@{Content='{"enabled":false}';Headers=@{}} }
        $row=Invoke-MtTest -Id CIS.GH.1.1.12 -Config (Get-CisBranchFixtureConfig)
        $row.Result | Should -Be 'Failed'
        $row.ResultDetail.TestResult | Should -Match 'b100'
        $row.ResultDetail.TestResult | Should -Match 'Evaluated branch findings: 101; displayed: 100'
    }

}
