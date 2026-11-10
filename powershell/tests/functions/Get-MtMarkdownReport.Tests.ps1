BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force
}

Describe 'Markdown failure messages' {
    It 'Renders every <Shape> error without changing its records' -ForEach @(
        @{ Shape = 'original' }, @{ Shape = 'deserialized' }
    ) {
        $first = [System.Management.Automation.ErrorRecord]::new([System.Exception]::new('Underlying exception'), 'Fixture', 'NotSpecified', $null)
        $first.ErrorDetails = [System.Management.Automation.ErrorDetails]::new('Detailed failure')
        $second = [System.Management.Automation.ErrorRecord]::new([System.Exception]::new('Second failure'), 'Fixture', 'NotSpecified', $null)
        $errors = @($first, $second)
        if ($Shape -eq 'deserialized') { $errors = $errors | ConvertTo-Json -Depth 5 | ConvertFrom-Json }
        $source = [pscustomobject]@{ Tests = @([pscustomobject]@{ Name = 'Fixture'; Result = 'Failed'; ScriptBlock = 'Invoke-Fixture'; ErrorRecord = $errors }) }
        $before = $source | ConvertTo-Json -Depth 10
        $markdown = InModuleScope Maester -Parameters @{ Source = $source } { Get-MtMarkdownReport -MaesterResults $Source }
        $markdown | Should -Match '#### Reason for failure\s+Detailed failure\s+Second failure'
        $markdown | Should -Not -Match 'Underlying exception|System.Management.Automation|@\{'
        ($source | ConvertTo-Json -Depth 10) | Should -BeExactly $before
    }
}

Describe 'Pester failure Markdown through Invoke-Maester' {
    BeforeAll {
        $fixture = Join-Path $TestDrive 'suite/Custom'
        $null = New-Item $fixture -ItemType Directory -Force
        @'
BeforeAll { $script:failureMessage = 'Runtime failure for RAW_FIXTURE_USER' }
Describe 'Export fixture' {
    It 'Custom.Failure: reports the runtime error' { throw $script:failureMessage }
}
'@ | Set-Content (Join-Path $fixture 'Failure.Tests.ps1')
        # A child process keeps the custom Pester run separate from this unit-test run.
        $runner = Join-Path $TestDrive 'run.ps1'
        @'
param($Manifest, $PesterManifest, $Fixture, $OutputRoot)
$ErrorActionPreference = 'Stop'
Import-Module $PesterManifest
Import-Module $Manifest
& (Get-Module Maester) { function script:Get-MtUserIdentityReplacementMap { @{ RAW_FIXTURE_USER = 'SAFE_FIXTURE_USER' } } }
foreach ($mode in 'None', 'HtmlOnly', 'AllOutputs') {
    $folder = Join-Path $OutputRoot $mode
    $result = Invoke-Maester -Path $Fixture -Config @{ GlobalSettings = @{} } -SkipBuiltIn -SkipPack -SkipGraphConnect -PassThru -NonInteractive -DisableTelemetry -SkipVersionCheck -NoLogo -RedactUserIdentity $mode -OutputFolder $folder -OutputFolderFileName result
    $row = $result.Tests | Where-Object Id -EQ 'Custom.Failure'
    [pscustomobject]@{ Result = $row.Result; ErrorType = $row.ErrorRecord[0].GetType().FullName; Message = $row.ErrorRecord[0].Exception.Message } |
        ConvertTo-Json | Set-Content (Join-Path $folder 'passthru.json')
}
'@ | Set-Content $runner
        $manifest = (Resolve-Path "$PSScriptRoot/../../Maester.psd1").Path
        $pesterManifest = Join-Path (Get-Module Pester).ModuleBase 'Pester.psd1'
        $output = & pwsh -NoProfile -NonInteractive -File $runner -Manifest $manifest -PesterManifest $pesterManifest -Fixture $fixture -OutputRoot $TestDrive 2>&1
        if ($LASTEXITCODE -ne 0) { throw "Export fixture failed: $output" }
    }

    It 'Keeps readable failure evidence and caller records in <Mode> mode' -ForEach @(
        @{ Mode = 'None' }, @{ Mode = 'HtmlOnly' }, @{ Mode = 'AllOutputs' }
    ) {
        $folder = Join-Path $TestDrive $Mode
        $markdown = Get-Content (Join-Path $folder 'result.md') -Raw
        $json = Get-Content (Join-Path $folder 'result.json') -Raw
        $expected = if ($Mode -eq 'AllOutputs') { 'SAFE_FIXTURE_USER' } else { 'RAW_FIXTURE_USER' }
        $markdown | Should -Match "#### Reason for failure\s+Runtime failure for $expected"
        $saved = $json | ConvertFrom-Json
        $saved.Tests[0].ErrorRecord[0].Exception.Message | Should -Be "Runtime failure for $expected"
        if ($Mode -eq 'AllOutputs') {
            $markdown | Should -Not -Match 'RAW_FIXTURE_USER'
            $json | Should -Not -Match 'RAW_FIXTURE_USER'
        }
        $original = Get-Content (Join-Path $folder 'passthru.json') -Raw | ConvertFrom-Json
        $original.Result | Should -Be 'Error'
        $original.ErrorType | Should -Be 'System.Management.Automation.ErrorRecord'
        $original.Message | Should -Be 'Runtime failure for RAW_FIXTURE_USER'
    }
}
