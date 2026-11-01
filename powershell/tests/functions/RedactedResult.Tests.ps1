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
    BeforeEach {
        Mock Get-MtUserIdentityReplacementMap -ModuleName Maester { @{ RAW_GENERIC_IDENTITY = 'SAFE_GENERIC_IDENTITY' } }
        $testPath = Join-Path $TestDrive 'fixture'
        $null = New-Item $testPath -ItemType Directory -Force
        @'
function Test-CustomExportFixture {
    [MaesterTest(Id = 'Custom.ExportFixture', Title = 'Export fixture RAW_GENERIC_IDENTITY', Service = 'None')]
    [CmdletBinding()]
    param()
    Add-MtTestResultDetail -Result 'RAW_FIXTURE_IDENTITY' -RedactedResult 'SAFE_FIXTURE_IDENTITY'
    return $true
}
'@ | Set-Content (Join-Path $testPath 'Test.Custom.ExportFixture.ps1')
        'Export fixture' | Set-Content (Join-Path $testPath 'Test.Custom.ExportFixture.md')
        $script:invokeParameters = @{
            Path = $testPath; PassThru = $true; SkipBuiltIn = $true; SkipPack = $true
            SkipGraphConnect = $true; NonInteractive = $true; DisableTelemetry = $true
            SkipVersionCheck = $true; NoLogo = $true; OutputFolderFileName = 'result'
        }
    }

    It 'Prepares independent output copies in <Mode> mode with <XmlFormat>' -ForEach @(
        @{ Mode = 'None'; XmlFormat = 'JUnitXml' }, @{ Mode = 'HtmlOnly'; XmlFormat = 'JUnitXml' }, @{ Mode = 'AllOutputs'; XmlFormat = 'JUnitXml' }
        @{ Mode = 'None'; XmlFormat = 'NUnitXml' }, @{ Mode = 'HtmlOnly'; XmlFormat = 'NUnitXml' }, @{ Mode = 'AllOutputs'; XmlFormat = 'NUnitXml' }
    ) {
        $folder = Join-Path $TestDrive "$Mode-$XmlFormat"
        $xmlPath = Join-Path $folder 'result.xml'
        $config = @{ GlobalSettings = @{}; Output = @{ TestResult = @{ Path = $xmlPath; Format = $XmlFormat } } }
        $result = Invoke-Maester @script:invokeParameters -Config $config -OutputFolder $folder -ExportCsv -RedactUserIdentity $Mode
        $row = $result.Tests | Where-Object Id -EQ 'Custom.ExportFixture'
        $row.Result | Should -Be 'Passed'
        $row.ResultDetail.TestResult | Should -Match 'RAW_FIXTURE_IDENTITY'
        $row.ResultDetail.TestResultRedacted | Should -Match 'SAFE_FIXTURE_IDENTITY'
        $row.Title | Should -Match 'RAW_GENERIC_IDENTITY'
        $csvRow = Import-Csv (Join-Path $folder 'result.csv') | Where-Object ID -EQ 'Custom.ExportFixture'
        $csvRow | Should -Not -BeNullOrEmpty
        $csvRow.Result | Should -Be 'Passed'
        $csvRow.ResultDetail | Should -Match $(if ($Mode -eq 'AllOutputs') { 'SAFE_FIXTURE_IDENTITY' } else { 'RAW_FIXTURE_IDENTITY' })
        foreach ($extension in 'json', 'html', 'md', 'csv') {
            $content = Get-Content (Join-Path $folder "result.$extension") -Raw
            $content | Should -Not -Match 'TestResultRedacted'
            if ($Mode -eq 'AllOutputs' -or ($Mode -eq 'HtmlOnly' -and $extension -eq 'html')) {
                $content | Should -Match 'SAFE_FIXTURE_IDENTITY'
                $content | Should -Not -Match 'RAW_FIXTURE_IDENTITY'
                $content | Should -Match 'SAFE_GENERIC_IDENTITY'
                $content | Should -Not -Match 'RAW_GENERIC_IDENTITY'
            } else {
                $content | Should -Match 'RAW_FIXTURE_IDENTITY'
                $content | Should -Not -Match 'SAFE_FIXTURE_IDENTITY'
                $content | Should -Match 'RAW_GENERIC_IDENTITY'
                $content | Should -Not -Match 'SAFE_GENERIC_IDENTITY'
            }
        }

        # XML projects names and outcomes, not the scoped Markdown detail.
        $xmlContent = Get-Content $xmlPath -Raw
        $xml = [xml]$xmlContent
        $cases = @($xml.SelectNodes('//testcase | //test-case'))
        $cases.Count | Should -Be 1
        $cases[0].name | Should -Match 'Export fixture'
        $cases[0].SelectNodes('failure | skipped | reason').Count | Should -Be 0
        if ($XmlFormat -eq 'NUnitXml') { $cases[0].result | Should -Be 'Success' }
        $xmlContent | Should -Not -Match 'TestResultRedacted|RAW_FIXTURE_IDENTITY|SAFE_FIXTURE_IDENTITY'
        if ($Mode -eq 'AllOutputs') {
            $cases[0].name | Should -Match 'SAFE_GENERIC_IDENTITY'
            $xmlContent | Should -Not -Match 'RAW_GENERIC_IDENTITY'
        } else {
            $cases[0].name | Should -Match 'RAW_GENERIC_IDENTITY'
            $xmlContent | Should -Not -Match 'SAFE_GENERIC_IDENTITY'
        }
    }

    It 'Writes and reads an XLSX workbook in <Mode> mode' -ForEach @(
        @{ Mode = 'None' }, @{ Mode = 'HtmlOnly' }, @{ Mode = 'AllOutputs' }
    ) {
        if (-not (Get-Module -ListAvailable ImportExcel)) {
            Set-ItResult -Skipped -Because 'ImportExcel is required for the XLSX round-trip fixture.'
            return
        }
        Import-Module ImportExcel
        $folder = Join-Path $TestDrive "$Mode-xlsx"
        $result = Invoke-Maester @script:invokeParameters -Config @{ GlobalSettings = @{} } -OutputFolder $folder -ExportExcel -RedactUserIdentity $Mode
        $workbook = Join-Path $folder 'result.xlsx'
        $workbook | Should -Exist
        $rows = @(Import-Excel -Path $workbook -WorksheetName Results)
        $rows.Count | Should -Be 1
        $rows[0].ID | Should -Be 'Custom.ExportFixture'
        $rows[0].Result | Should -Be 'Passed'
        $content = $rows | ConvertTo-Json -Depth 5
        $content | Should -Not -Match 'TestResultRedacted'
        if ($Mode -eq 'AllOutputs') {
            $rows[0].ResultDetail | Should -Match 'SAFE_FIXTURE_IDENTITY'
            $rows[0].Title | Should -Match 'SAFE_GENERIC_IDENTITY'
            $content | Should -Not -Match 'RAW_FIXTURE_IDENTITY|RAW_GENERIC_IDENTITY'
        } else {
            $rows[0].ResultDetail | Should -Match 'RAW_FIXTURE_IDENTITY'
            $rows[0].Title | Should -Match 'RAW_GENERIC_IDENTITY'
            $content | Should -Not -Match 'SAFE_FIXTURE_IDENTITY|SAFE_GENERIC_IDENTITY'
        }
        $row = $result.Tests | Where-Object Id -EQ 'Custom.ExportFixture'
        $row.ResultDetail.TestResult | Should -Match 'RAW_FIXTURE_IDENTITY'
        $row.ResultDetail.TestResultRedacted | Should -Match 'SAFE_FIXTURE_IDENTITY'
        $row.Title | Should -Match 'RAW_GENERIC_IDENTITY'
    }
}
