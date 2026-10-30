BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force
}

Describe 'Scoped redacted result Markdown' {
    BeforeEach {
        InModuleScope Maester { $__MtSession.TestResultDetail = @{} }
        Mock Get-MtTestResultTemplate -ModuleName Maester { @{ Description = 'Static guide'; Result = 'Static wrapper: %TestResult%' } }
        Mock Get-GraphObjectMarkdown -ModuleName Maester { 'RAW_GRAPH_IDENTITY' }
    }
    It 'Applies the static template to both variants without putting GraphObjects into the alternative' {
        Add-MtTestResultDetail -TestName 'fixture' -Result 'Raw: %TestResult%' -RedactedResult 'Safe: object-test' -GraphObjects @(@{ id = '1' }) -GraphObjectType Users
        $detail = InModuleScope Maester { $__MtSession.TestResultDetail.fixture }
        $detail.TestResult | Should -Be 'Static wrapper: Raw: RAW_GRAPH_IDENTITY'
        $detail.TestResultRedacted | Should -Be 'Static wrapper: Safe: object-test'
    }
    It 'Preserves the positional binding of existing parameters' {
        $command = Get-Command Add-MtTestResultDetail
        ($command.ParameterSets[0].Parameters | Where-Object Name -EQ 'GraphObjects').Position | Should -Contain 2
        ($command.ParameterSets[0].Parameters | Where-Object Name -EQ 'Severity').Position | Should -Contain 9
    }
    It 'Does not add optional metadata for existing callers' {
        Add-MtTestResultDetail -TestName 'fixture' -Result 'Raw'
        InModuleScope Maester { $__MtSession.TestResultDetail.fixture.ContainsKey('TestResultRedacted') } | Should -BeFalse
    }
    It 'Rejects an explicitly supplied blank alternative: <Label>' -ForEach @(
        @{ Label = 'null'; Value = $null }, @{ Label = 'empty'; Value = '' }, @{ Label = 'whitespace'; Value = " `n " }
    ) {
        { Add-MtTestResultDetail -TestName 'fixture' -Result 'Raw' -RedactedResult $Value } | Should -Throw
    }
    It 'Copies <Shape> results and removes the alternative independently of the generic map' -ForEach @(
        @{ Shape = 'single' }, @{ Shape = 'merged' }, @{ Shape = 'hashtable' }
    ) {
        $tenant = [pscustomobject]@{ Tests = @([pscustomobject]@{ Id = 'CIS.GH.1.2.3'; Result = 'Failed'; ResultDetail = [pscustomobject]@{ TestResult = 'raw-user'; TestResultRedacted = 'object-test; 2 administrators'; TestDescription = 'Guide' } }) }
        $source = switch ($Shape) {
            'merged' { Merge-MtMaesterResult -MaesterResults @($tenant, $tenant) }
            'hashtable' { @{ Tests = @(@{ Id = 'CIS.GH.1.2.3'; Result = 'Failed'; ResultDetail = @{ TestResult = 'raw-user'; TestResultRedacted = 'object-test; 2 administrators'; TestDescription = 'Guide' } }) } }
            default { $tenant }
        }
        $before = ConvertTo-Json -InputObject $source -Depth 15
        $prepared = InModuleScope Maester -Parameters @{ Source = $source } { ConvertTo-MtRedactedResult -MaesterResults $Source -ReplacementMap @{} }
        $json = ConvertTo-Json -InputObject $prepared -Depth 15
        $json | Should -Not -Match 'raw-user|TestResultRedacted'
        $json | Should -Match 'object-test; 2 administrators'
        $json | Should -Match 'CIS.GH.1.2.3'
        (ConvertTo-Json -InputObject $source -Depth 15) | Should -BeExactly $before
        $html = Get-MtHtmlReport -MaesterResults $source -RedactUserIdentity HtmlOnly -UserIdentityReplacementMap @{}
        $html | Should -Not -Match 'raw-user|TestResultRedacted'
        $html | Should -Match 'object-test; 2 administrators'
        (ConvertTo-Json -InputObject $source -Depth 15) | Should -BeExactly $before
    }
    It 'Continues generic replacement on other fields' {
        $source = [pscustomobject]@{ Title = 'Jane Smith'; Tests = @([pscustomobject]@{ ResultDetail = @{ TestResult = 'Raw'; TestResultRedacted = 'Safe Jane Smith' } }) }
        $prepared = InModuleScope Maester -Parameters @{ Source = $source } { ConvertTo-MtRedactedResult -MaesterResults $Source -ReplacementMap @{ 'Jane Smith' = 'object-generic' } }
        $prepared.Title | Should -Be 'object-generic'
        $prepared.Tests[0].ResultDetail.TestResult | Should -Be 'Safe object-generic'
        $source.Title | Should -Be 'Jane Smith'
    }
    It 'Fails closed when imported alternative metadata is unusable' {
        InModuleScope Maester {
            { ConvertTo-MtRedactedResult -MaesterResults @{ Tests = @(@{ ResultDetail = @{ TestResult = 'raw'; TestResultRedacted = '' } }) } } | Should -Throw '*complete nonblank*'
        }
    }
    It 'Uses host-scoped stable pseudonyms without replacing numeric facts or Markdown syntax' {
        InModuleScope Maester {
            $evidence = @{
                ApiAuthority = 'https://API.GITHUB.COM:443/'; OwnerBranch = $true; Field = 'members_can_delete_issues'; Setting = $false
                OrganizationId = 2; MaximumOrganizationOwners = 3; Owners = @(@{ id = 2; login = '2' }, @{ id = 3; login = 'a|b`x' })
                ApprovalsConfigured = $true; ApprovedOwnerIds = @('2'); OwnerComplete = $true; Gaps = @(); Message = 'CIS.GH.1.2.3'
            }
            $raw = Get-MtCisGitHubDeletionResult -Evidence $evidence
            $safe = Get-MtCisGitHubDeletionResult -Evidence $evidence -RedactUserIdentity
            $raw | Should -Match ([regex]::Escape((Get-MtSafeMarkdown 'a|b`x')))
            $safe | Should -Not -Match 'a\\?\|b|\| 2 \| 2 \| Approved'
            $safe | Should -Match '\| 2 \| 3 \| 1 \| Complete'
            $safe | Should -Match 'Organization ID: `2`'
            $safe | Should -Match 'CIS.GH.1.2.3'
            $expected = Get-MtAffectedObjectUniqueId -System GitHub -Type User -Id 'https://api.github.com/users/2'
            $safe | Should -Match ([regex]::Escape("| $expected | $expected | Approved |"))
            $evidence.ApiAuthority = 'https://api.fixture.ghe.com'
            $otherHost = Get-MtCisGitHubDeletionResult -Evidence $evidence -RedactUserIdentity
            $otherHost | Should -Not -Match $expected
            $evidence.OwnerBranch = $false
            $evidence.Repositories = @(@{ Name = 'fixture'; AdministratorCount = 3; UnapprovedIds = @('2'); Complete = $false; ApprovalsConfigured = $true; Assessment = 'Needs review' })
            $admin = Get-MtCisGitHubDeletionResult -Evidence $evidence -RedactUserIdentity
            $otherToken = Get-MtAffectedObjectUniqueId -System GitHub -Type User -Id 'https://api.fixture.ghe.com/users/2'
            $otherHost | Should -Match $otherToken
            $admin | Should -Match $otherToken
            $admin | Should -Match '\| fixture \| 3 \| 1 \|'
        }
    }
}
