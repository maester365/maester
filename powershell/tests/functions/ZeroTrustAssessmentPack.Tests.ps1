Describe 'Zero Trust Assessment pack' {
    BeforeAll {
        Import-Module $PSScriptRoot/../../Maester.psd1 -Force -WarningAction SilentlyContinue
        $script:PackRoot = (Resolve-Path "$PSScriptRoot/../../../packs/zero-trust-assessment").Path
        $script:TestsPath = Join-Path $script:PackRoot 'tests'
        $script:Fixture = (Resolve-Path "$PSScriptRoot/../fixtures/zero-trust-assessment").Path

        # The fixture is a cut of the assessment's own sample report: two rows of each status, a Defender for
        # Cloud ID that repeats with different titles, and one row that repeats exactly.
        function Invoke-ZtaPack {
            param([hashtable] $Setting = @{})
            $globalSettings = @{ 'ZeroTrustAssessment.ReportPath' = $script:Fixture; 'ZeroTrustAssessment.MaxReportAgeDays' = 0 }
            foreach ($key in $Setting.Keys) { $globalSettings[$key] = $Setting[$key] }
            $config = [pscustomobject]@{
                GlobalSettings = [pscustomobject]$globalSettings
                Environment    = [pscustomobject]@{ Enforce = [pscustomobject]@{ Service = $false } }
            }
            @(Invoke-MtTest -Path $script:TestsPath -Id ZTA -Config $config)
        }

        $script:Rows = Invoke-ZtaPack

        # The attachments the last run added, or nothing on a Maester version without Add-MtReportAttachment.
        function Get-ZtaAttachment {
            InModuleScope Maester { @($__MtSession.ReportAttachments | Where-Object { $_ }) }
        }
        function Clear-ZtaAttachment {
            InModuleScope Maester { $__MtSession.ReportAttachments = $null }
        }
        $script:CanAttach = [bool](Get-Command -Name Add-MtReportAttachment -ErrorAction Ignore)
    }

    AfterEach {
        # Removes only the stand-in a test defined, never a Get-MgContext a module exports.
        Get-Item -Path function:Get-MgContext -ErrorAction SilentlyContinue | Where-Object { -not $_.Module } | Remove-Item
    }

    Context 'the pack files' {
        It 'has a valid native test' {
            $test = Get-MtTest -Path (Join-Path $script:TestsPath 'Test.ZTA.ps1')
            $test.IsValid | Should -BeTrue
            $test.Errors | Should -BeNullOrEmpty
            $test.LongRunning | Should -BeTrue
            $test.InstanceSource | Should -Be 'Get-MtZtaInstance'
            $test.Suite | Should -Be 'ZTA'
        }

        It 'has a manifest with the pack code' {
            $manifest = Get-Content (Join-Path $script:PackRoot 'maester-pack.json') -Raw | ConvertFrom-Json
            $manifest.Id | Should -Be 'maester.zero-trust-assessment'
            $manifest.Code | Should -Be 'ZTA'
            $manifest.Uses.GraphScopes | Should -Be @($manifest.Uses.GraphScopes | Sort-Object -Unique)
        }

        It 'has a catalog of unique ZTA IDs' {
            $catalog = Get-Content (Join-Path $script:PackRoot 'catalog.json') -Raw | ConvertFrom-Json
            $catalog.ModuleVersion | Should -Not -BeNullOrEmpty
            $catalog.Tests.Count | Should -BeGreaterThan 0
            @($catalog.Tests.Id | Where-Object { $_ -notmatch '^ZTA\.\d+$' }) | Should -BeNullOrEmpty
            @($catalog.Tests.Id | Sort-Object -Unique).Count | Should -Be $catalog.Tests.Count
            @($catalog.Tests | Where-Object { [string]::IsNullOrWhiteSpace($_.Title) }) | Should -BeNullOrEmpty
        }
    }

    Context 'reading a report' {
        It 'writes one row per assessment result and leaves out planned tests' {
            $script:Rows.Count | Should -Be 12
            $script:Rows.Id | Should -Not -Contain 'ZTA.21821'
            $script:Rows.Id | Should -Not -Contain 'ZTA.21894'
            @($script:Rows | Where-Object ParentId -ne 'ZTA') | Should -BeNullOrEmpty
        }

        It 'maps <Id> to <Result>' -ForEach @(
            @{ Id = 'ZTA.24542'; Result = 'Passed' }
            @{ Id = 'ZTA.21828'; Result = 'Failed' }
            @{ Id = 'ZTA.25481'; Result = 'Investigate' }
            @{ Id = 'ZTA.21955'; Result = 'Skipped' }
            @{ Id = 'ZTA.24548'; Result = 'Error' }
        ) {
            ($script:Rows | Where-Object Id -eq $Id).Result | Should -Be $Result
        }

        It 'keeps the assessment title, risk level and pillar' {
            $row = $script:Rows | Where-Object Id -eq 'ZTA.21828'
            $row.Title | Should -Be 'Authentication transfer is blocked'
            $row.Severity | Should -Be 'High'
            $row.Tag | Should -Contain 'ZeroTrust.Identity'
            $row.ResultDetail.TestDescription | Should -BeLike 'Blocking authentication transfer*'
            $row.ResultDetail.TestResult | Should -BeLike '*Authentication transfer is not blocked.*'
        }

        It 'uses Maester wording for a skip reason both tools share' {
            ($script:Rows | Where-Object Id -eq 'ZTA.21955').ReasonCode | Should -Be 'NotApplicable'
        }

        It 'gives rows that share an ID a stable suffix from their title' {
            $guidRows = @($script:Rows | Where-Object Id -like 'ZTA.55555555-5555-5555-5555-555555555555.*')
            $guidRows.Count | Should -Be 3
            @($guidRows.Id | Sort-Object -Unique).Count | Should -Be 3
            $guidRows.Id | Should -Contain 'ZTA.55555555-5555-5555-5555-555555555555.1b7e76ce09'
            $guidRows.Id | Should -Contain 'ZTA.55555555-5555-5555-5555-555555555555.1b7e76ce09.2'
            $script:Rows.Id | Should -Contain 'ZTA.77777777-7777-7777-7777-777777777777'
        }

        It 'embeds the assessment HTML report written beside the export' {
            if (-not $script:CanAttach) { Set-ItResult -Skipped -Because 'this Maester has no Add-MtReportAttachment' }
            $folder = New-Item -ItemType Directory -Path (Join-Path -Path $TestDrive -ChildPath 'zt' -AdditionalChildPath 'zt-export') -Force
            Copy-Item -LiteralPath (Join-Path $script:Fixture 'ZeroTrustAssessmentReport.json') -Destination $folder
            Set-Content -LiteralPath (Join-Path $TestDrive 'zt/ZeroTrustAssessmentReport.html') -Value '<html>zta</html>'
            Clear-ZtaAttachment

            $null = Invoke-ZtaPack -Setting @{ 'ZeroTrustAssessment.ReportPath' = (Join-Path $folder 'ZeroTrustAssessmentReport.json') }

            $attachment = @(Get-ZtaAttachment)
            $attachment.Count | Should -Be 1
            $attachment[0].Name | Should -Be 'Zero Trust Assessment'
            $attachment[0].TestId | Should -Be 'ZTA'
            $attachment[0].FileName | Should -Be 'ZeroTrustAssessmentReport.html'
        }

        It 'embeds nothing when the report has no HTML beside it, or when EmbedReport is false' {
            if (-not $script:CanAttach) { Set-ItResult -Skipped -Because 'this Maester has no Add-MtReportAttachment' }
            Clear-ZtaAttachment
            $null = Invoke-ZtaPack
            Get-ZtaAttachment | Should -BeNullOrEmpty

            $null = Invoke-ZtaPack -Setting @{ 'ZeroTrustAssessment.ReportPath' = (Join-Path $TestDrive 'zt'); 'ZeroTrustAssessment.EmbedReport' = $false }
            Get-ZtaAttachment | Should -BeNullOrEmpty
        }

        It 'skips the family when the report is missing' {
            $rows = Invoke-ZtaPack -Setting @{ 'ZeroTrustAssessment.ReportPath' = (Join-Path $TestDrive 'none') }
            $rows.Count | Should -Be 1
            $rows[0].Result | Should -Be 'Skipped'
            $rows[0].ReasonDetail | Should -BeLike '*No Zero Trust Assessment report was found*'
        }

        It 'skips the family when the report is too old' {
            $rows = Invoke-ZtaPack -Setting @{ 'ZeroTrustAssessment.MaxReportAgeDays' = 7 }
            $rows.Count | Should -Be 1
            $rows[0].Result | Should -Be 'Skipped'
            $rows[0].ReasonDetail | Should -BeLike '*more than 7 days ago*'
        }

        It 'skips the family when the report is for another tenant' {
            function global:Get-MgContext { [pscustomobject]@{ TenantId = '00000000-0000-0000-0000-000000000001' } }
            $rows = Invoke-ZtaPack
            $rows.Count | Should -Be 1
            $rows[0].Result | Should -Be 'Skipped'
            $rows[0].ReasonDetail | Should -BeLike '*is for tenant 22222222-2222-2222-2222-222222222222*'
        }
    }

    Context 'running the assessment' {
        BeforeAll {
            # A stand-in for the ZeroTrustAssessment module: it records what it was called with and writes the
            # fixture report where Invoke-ZtAssessment writes its own.
            $script:FakeModules = Join-Path $TestDrive 'modules'
            $moduleFolder = New-Item -ItemType Directory -Path (Join-Path -Path $script:FakeModules -ChildPath 'ZeroTrustAssessment' -AdditionalChildPath '9.9.9') -Force
            $script:CallLog = Join-Path $TestDrive 'calls.json'
            Set-Content -LiteralPath (Join-Path $moduleFolder 'ZeroTrustAssessment.psd1') -Value "@{ RootModule = 'ZeroTrustAssessment.psm1'; ModuleVersion = '9.9.9'; FunctionsToExport = 'Connect-ZtAssessment', 'Invoke-ZtAssessment' }"
            Set-Content -LiteralPath (Join-Path $moduleFolder 'ZeroTrustAssessment.psm1') -Value @"
function Connect-ZtAssessment { param([string] `$TenantId, [string] `$ClientId, `$Certificate, [string[]] `$Service) `$script:Connect = `$PSBoundParameters }
function Invoke-ZtAssessment {
    param([string] `$Path, [string] `$Pillar, [switch] `$NoBrowser, [switch] `$DisableTelemetry, [switch] `$ShowLog, [int] `$Days, [string[]] `$Tests, [string] `$ConfigurationFile)
    Write-Host "Running test 21828"
    Write-Progress -Activity 'Processing 1 Tests' -Status 'Completed: 1 / 1' -PercentComplete 100
    [Console]::Error.WriteLine('a line on stderr')
    `$export = New-Item -ItemType Directory -Path (Join-Path `$Path 'zt-export') -Force
    Copy-Item -LiteralPath '$(Join-Path $script:Fixture 'ZeroTrustAssessmentReport.json')' -Destination `$export
    Set-Content -LiteralPath (Join-Path `$Path 'ZeroTrustAssessmentReport.html') -Value '<html>zta</html>'
    `$config = if (`$ConfigurationFile) { Get-Content -LiteralPath `$ConfigurationFile -Raw | ConvertFrom-Json } else { `$null }
    @{ Connect = `$script:Connect; Assessment = `$PSBoundParameters; Config = `$config } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath '$($script:CallLog)'
}
"@
            $script:OriginalModulePath = $env:PSModulePath
            $env:PSModulePath = $script:FakeModules + [System.IO.Path]::PathSeparator + $env:PSModulePath
        }

        AfterAll {
            $env:PSModulePath = $script:OriginalModulePath
        }

        It 'runs the assessment in a child process and reads its report' {
            $output = Join-Path $TestDrive 'zt-output'
            $rows = Invoke-ZtaPack -Setting @{
                'ZeroTrustAssessment.ReportPath' = ''
                'ZeroTrustAssessment.OutputPath' = $output
                'ZeroTrustAssessment.Pillar'     = 'Identity'
                'ZeroTrustAssessment.Tests'      = @('21828')
                EmergencyAccessAccounts          = @([pscustomobject]@{ Type = 'User'; UserPrincipalName = 'breakglass@contoso.com' })
            }
            $rows.Count | Should -Be 12
            Test-Path (Join-Path -Path $output -ChildPath 'zt-export' -AdditionalChildPath 'ZeroTrustAssessmentReport.json') | Should -BeTrue

            $call = Get-Content -LiteralPath $script:CallLog -Raw | ConvertFrom-Json
            $call.Assessment.Path | Should -Be $output
            $call.Assessment.Pillar | Should -Be 'Identity'
            $call.Assessment.Tests | Should -Be @('21828')
            $call.Assessment.NoBrowser | Should -BeTrue
            $call.Assessment.DisableTelemetry | Should -BeTrue
            $call.Assessment.ShowLog | Should -BeTrue
            $call.Config.GlobalSettings.EmergencyAccessAccounts[0].UserPrincipalName | Should -Be 'breakglass@contoso.com'
        }

        It 'shows what the child writes while it runs, its progress as a line of progress' {
            $script:Shown = [System.Collections.Generic.List[object]]::new()
            Mock -ModuleName Maester Write-MtHostLine { $script:Shown.Add($Text) }
            $rows = Invoke-ZtaPack -Setting @{ 'ZeroTrustAssessment.ReportPath' = '' }
            $rows.Count | Should -Be 12
            # A console that shows colour, such as GitHub Actions, gets the lines styled.
            $shown = @($script:Shown -replace "`e\[[0-9;]*m", '')
            $shown | Should -Contain '  Microsoft Zero Trust Assessment 9.9.9'
            $shown | Should -Contain '    Running test 21828'
            $shown | Should -Contain '    Processing 1 Tests: Completed: 1 / 1 (100%)'
            $shown | Should -Contain '    a line on stderr'
            @($shown | Where-Object { $_ -match 'maester-progress' }) | Should -BeNullOrEmpty
        }

        It 'signs the child in with the app and certificate Maester uses' {
            function global:Get-MgContext {
                [pscustomobject]@{ TenantId = '22222222-2222-2222-2222-222222222222'; AuthType = 'AppOnly'; ClientId = 'app-id'; CertificateThumbprint = 'ABC123' }
            }
            $null = Invoke-ZtaPack -Setting @{ 'ZeroTrustAssessment.ReportPath' = '' }
            $call = Get-Content -LiteralPath $script:CallLog -Raw | ConvertFrom-Json
            $call.Connect.TenantId | Should -Be '22222222-2222-2222-2222-222222222222'
            $call.Connect.ClientId | Should -Be 'app-id'
            $call.Connect.Certificate | Should -Be 'ABC123'
        }

        It 'deletes a temporary output folder after reading it' {
            $before = @(Get-ChildItem -LiteralPath ([System.IO.Path]::GetTempPath()) -Filter 'maester-zta-*' -ErrorAction SilentlyContinue).Count
            $rows = Invoke-ZtaPack -Setting @{ 'ZeroTrustAssessment.ReportPath' = '' }
            $rows.Count | Should -Be 12
            @(Get-ChildItem -LiteralPath ([System.IO.Path]::GetTempPath()) -Filter 'maester-zta-*' -ErrorAction SilentlyContinue).Count | Should -Be $before
        }

        It 'embeds the assessment HTML report before deleting the temporary output folder' {
            if (-not $script:CanAttach) { Set-ItResult -Skipped -Because 'this Maester has no Add-MtReportAttachment' }
            Clear-ZtaAttachment
            $null = Invoke-ZtaPack -Setting @{ 'ZeroTrustAssessment.ReportPath' = '' }
            @(Get-ZtaAttachment).Name | Should -Be 'Zero Trust Assessment'
        }

        It 'skips the family when the module is not installed' {
            $env:PSModulePath = $script:OriginalModulePath
            try {
                $rows = Invoke-ZtaPack -Setting @{ 'ZeroTrustAssessment.ReportPath' = '' }
            } finally {
                $env:PSModulePath = $script:FakeModules + [System.IO.Path]::PathSeparator + $script:OriginalModulePath
            }
            $rows.Count | Should -Be 1
            $rows[0].Result | Should -Be 'Skipped'
            $rows[0].ReasonDetail | Should -BeLike '*ZeroTrustAssessment module is not installed*'
        }
    }
}
