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
    It 'Falls back to generic replacement for invalid imported metadata: <Label>' -ForEach @(
        @{ Label = 'null'; Value = $null }, @{ Label = 'empty'; Value = '' },
        @{ Label = 'blank'; Value = '  ' }, @{ Label = 'number'; Value = 123 }, @{ Label = 'object'; Value = @{} }
    ) {
        $source = @{ Tests = @(@{ ResultDetail = @{ TestResult = 'Jane Example'; TestResultRedacted = $Value } }) }
        $prepared = InModuleScope Maester -Parameters @{ Source = $source } {
            ConvertTo-MtRedactedResult -MaesterResults $Source -ReplacementMap @{ 'Jane Example' = 'object-generic' }
        }
        $prepared.Tests[0].ResultDetail.TestResult | Should -Be 'object-generic'
        ($prepared | ConvertTo-Json -Depth 15) | Should -Not -Match 'TestResultRedacted'
        $source.Tests[0].ResultDetail.TestResult | Should -Be 'Jane Example'
    }
    It 'Omits alternative metadata from unredacted HTML while preserving input' {
        $source = @{ Tests = @(@{ ResultDetail = @{ TestResult = 'raw-user'; TestResultRedacted = 'safe-user' } }) }
        $html = Get-MtHtmlReport -MaesterResults $source -RedactUserIdentity None
        $html | Should -Match 'raw-user'
        $html | Should -Not -Match 'safe-user|TestResultRedacted'
        $source.Tests[0].ResultDetail.TestResultRedacted | Should -Be 'safe-user'
    }

}

Describe 'Scoped result export modes through Invoke-Maester' {
    It 'Prepares independent output copies in <Mode> mode' -ForEach @(
        @{ Mode = 'None' }, @{ Mode = 'HtmlOnly' }, @{ Mode = 'AllOutputs' }
    ) {
        Mock Get-MtUserIdentityReplacementMap -ModuleName Maester { @{} }
        $testPath = Join-Path $TestDrive 'fixture'
        $null = New-Item $testPath -ItemType Directory -Force
        @'
function Test-CustomExportFixture {
    [MaesterTest(Id = 'Custom.ExportFixture', Title = 'Export fixture', Service = 'None')]
    [CmdletBinding()]
    param()
    Add-MtTestResultDetail -Result 'RAW_FIXTURE_IDENTITY' -RedactedResult 'SAFE_FIXTURE_IDENTITY'
    return $true
}
'@ | Set-Content (Join-Path $testPath 'Test.Custom.ExportFixture.ps1')
        'Export fixture' | Set-Content (Join-Path $testPath 'Test.Custom.ExportFixture.md')
        $folder = Join-Path $TestDrive $Mode
        $result = Invoke-Maester -Path $testPath -Config @{ GlobalSettings = @{} } -PassThru -SkipGraphConnect -NonInteractive -DisableTelemetry -SkipVersionCheck -NoLogo -OutputFolder $folder -OutputFolderFileName result -RedactUserIdentity $Mode
        $row = $result.Tests | Where-Object Id -EQ 'Custom.ExportFixture'
        $row.Result | Should -Be 'Passed'
        $row.ResultDetail.TestResult | Should -Match 'RAW_FIXTURE_IDENTITY'
        $row.ResultDetail.TestResultRedacted | Should -Match 'SAFE_FIXTURE_IDENTITY'
        foreach ($extension in 'json', 'html', 'md') {
            $content = Get-Content (Join-Path $folder "result.$extension") -Raw
            $content | Should -Not -Match 'TestResultRedacted'
            if ($Mode -eq 'AllOutputs' -or ($Mode -eq 'HtmlOnly' -and $extension -eq 'html')) {
                $content | Should -Match 'SAFE_FIXTURE_IDENTITY'
                $content | Should -Not -Match 'RAW_FIXTURE_IDENTITY'
            } else {
                $content | Should -Match 'RAW_FIXTURE_IDENTITY'
                $content | Should -Not -Match 'SAFE_FIXTURE_IDENTITY'
            }
        }
    }
}
