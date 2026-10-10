BeforeAll {
    $script:RepoRoot = (Resolve-Path "$PSScriptRoot/../../..").Path
    $script:EidscaBuildScript = Join-Path $script:RepoRoot 'build/eidsca/Update-EidscaTests.ps1'

    function Get-NormalizedContent {
        param([string] $Path)
        if (-not (Test-Path -LiteralPath $Path)) { return $null }
        return ([System.IO.File]::ReadAllText($Path) -replace "`r`n", "`n")
    }

    function New-GeneratorOutput {
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Test helper.')]
        param([string] $Root)
        $paths = @{
            TestPath                = Join-Path $Root 'tests'
            PowerShellFunctionsPath = Join-Path $Root 'internal'
            PublicFunctionPath      = Join-Path $Root 'public'
        }
        foreach ($path in $paths.Values) { $null = New-Item -Path $path -ItemType Directory -Force }
        $paths
    }
}

Describe 'EIDSCA generator' {
    It 'does not manage generated website test documentation' {
        $scriptContent = Get-Content -Path $script:EidscaBuildScript -Raw

        $scriptContent | Should -Not -Match 'DocsPath'
        $scriptContent | Should -Not -Match 'website[/\\]docs[/\\]tests'
    }

    It 'generates canonical sources from fixture input' {
        $paths = New-GeneratorOutput -Root $TestDrive
        $configPath = Join-Path $TestDrive 'EidscaConfig.json'
        $fixtureJson = @'
[
  {
    "CollectedBy": "Maester",
    "ControlArea": [
      {
        "ControlName": "Fixture control",
        "Description": "Fixture control description",
        "Discovery": ["$FixtureDiscovery = $true"],
        "GraphUri": "https://graph.microsoft.com/v1.0/fixture/settings",
        "GraphEndpoint": "fixture/settings",
        "GraphDocsUrl": "",
        "Controls": [
          {
            "CheckId": "EIDSCA.ZZ99",
            "Name": "FixtureSetting",
            "DisplayName": "Fixture setting",
            "Description": "Fixture setting description",
            "Severity": "Medium",
            "RecommendedValue": "true",
            "DefaultValue": "false",
            "CurrentValue": "isEnabled",
            "Recommendation": "",
            "PortalDeepLink": "",
            "HowToFix": "Use [the portal](https://example.invalid) or run: ```$literal $$ $& $1```",
            "MitreTactic": [],
            "MitreTechnique": [],
            "MitreMitigation": [],
            "SkipCondition": "",
            "SkipReason": ""
          },
          {
            "CheckId": "EIDSCA.ZZ98",
            "Name": "WhitespaceRemediation",
            "DisplayName": "Whitespace remediation",
            "Description": "Whitespace remediation description",
            "Severity": "Medium",
            "RecommendedValue": ">=30",
            "DefaultValue": "60",
            "CurrentValue": "duration",
            "Recommendation": "",
            "PortalDeepLink": "",
            "HowToFix": "   ",
            "MitreTactic": [],
            "MitreTechnique": [],
            "MitreMitigation": [],
            "SkipCondition": "$EntraIDPlan -eq 'Free'",
            "SkipReason": "Needs Entra ID P1"
          },
          {
            "CheckId": "EIDSCA.ZZ97",
            "Name": "BlankRemediation",
            "DisplayName": "Blank remediation",
            "Description": "Blank remediation description",
            "Severity": "Informational",
            "RecommendedValue": "@('a','b')",
            "DefaultValue": "false",
            "CurrentValue": "mode",
            "Recommendation": "",
            "PortalDeepLink": "",
            "HowToFix": "",
            "MitreTactic": [],
            "MitreTechnique": [],
            "MitreMitigation": [],
            "SkipCondition": "$FixtureDiscovery -ne $true -or (Test-MtEidscaZZ99) -eq $false",
            "SkipReason": "Fixture setting isn't enabled"
          }
        ]
      }
    ]
  }
]
'@
        [System.IO.File]::WriteAllText($configPath, $fixtureJson)
        $seedPath = Join-Path $TestDrive 'seed.csv'
        "test_id,author,contributors_recommended`nEIDSCA.ZZ99,fixture-author,fixture-contributor;fixture-author" | Set-Content -Path $seedPath
        $maesterConfigPath = Join-Path $TestDrive 'maester-config.json'
        '{ "TestSettings": [ { "Id": "EIDSCA.ZZ99", "Severity": "Critical" } ] }' | Set-Content -Path $maesterConfigPath
        Mock Invoke-WebRequest { throw 'The generator must not use the network without -Download.' }

        & $script:EidscaBuildScript @paths `
            -ConfigPath $configPath `
            -PageTitleCachePath (Join-Path $TestDrive 'PageTitles.json') `
            -MaesterConfigPath $maesterConfigPath `
            -AuthorshipPath $seedPath

        Join-Path $paths.PowerShellFunctionsPath 'Test-MtEidscaZZ99.ps1' | Should -Exist
        Join-Path $paths.PowerShellFunctionsPath 'Test-MtEidscaZZ99.md' | Should -Not -Exist
        Join-Path $paths.PublicFunctionPath 'Test-MtEidscaControl.ps1' | Should -Exist
        $nativePath = Join-Path $paths.TestPath 'Test.EIDSCA.ZZ99.ps1'
        $nativePath | Should -Exist
        $remediationMarkdownPath = Join-Path $paths.TestPath 'Test.EIDSCA.ZZ99.md'
        $remediationMarkdownPath | Should -Exist

        $expectedRemediation = @'
#### Remediation action

Use [the portal](https://example.invalid) or run: ```$literal $$ $& $1```
'@
        $expectedRemediation = $expectedRemediation.Trim() -replace '\r\n?', "`n"
        $remediationMarkdown = Get-Content -Path $remediationMarkdownPath -Raw
        $remediationMarkdown = $remediationMarkdown -replace '\r\n?', "`n"
        $remediationMarkdown.Contains($expectedRemediation) | Should -BeTrue
        Get-Content -Path (Join-Path $paths.TestPath 'Test.EIDSCA.ZZ98.md') -Raw | Should -Not -Match 'Remediation action'
        Get-Content -Path (Join-Path $paths.TestPath 'Test.EIDSCA.ZZ97.md') -Raw | Should -Not -Match 'Remediation action'
        Should -Invoke Invoke-WebRequest -Times 0 -Exactly

        # The native test: attribute from the config row and the authorship seed, and the 2.x comparison.
        $native = Get-Content -Path $nativePath -Raw
        $native | Should -Match "Id = 'EIDSCA.ZZ99'"
        $native | Should -Match "Title = 'Fixture control - Fixture setting.'"
        $native | Should -Match "Severity = 'Critical'"
        $native | Should -Match "Category = 'EIDSCA'"
        $native | Should -Match "Service = 'Graph'"
        $native | Should -Match "Author = 'fixture-author'"
        $native | Should -Match "Contributor = 'fixture-contributor'"
        $native | Should -Not -Match 'HelpUrl'
        $native | Should -Match "return \(\`$tenantValue -eq 'true'\)"

        # A licence skip becomes License; the severity falls back to the EIDSCA config.
        $licensed = Get-Content -Path (Join-Path $paths.TestPath 'Test.EIDSCA.ZZ98.ps1') -Raw
        $licensed | Should -Match "License = 'AAD_PREMIUM'"
        $licensed | Should -Match "Severity = 'Medium'"
        $licensed | Should -Match "Author = 'Cloud-Architekt'"
        $licensed | Should -Not -Match 'EntraIDPlan'
        $licensed | Should -Match 'return \(\$tenantValue -ge 30\)'

        # Other skips stay in the test, read their discovery variable, and never call another test.
        $skipped = Get-Content -Path (Join-Path $paths.TestPath 'Test.EIDSCA.ZZ97.ps1') -Raw
        $skipped | Should -Match "Severity = 'Info'"
        $skipped | Should -Match '\$FixtureDiscovery = \$true'
        $skipped | Should -Not -Match '\(Test-MtEidscaZZ99\)'
        $skipped | Should -Match 'Invoke-MtGraphRequest -RelativeUri "fixture/settings" -ApiVersion v1.0'
        $skipped | Should -Match "SkippedCustomReason 'Fixture setting isn''t enabled'"
        $skipped | Should -Match "return \(\`$tenantValue -in @\('a','b'\)\)"

        # Every generated native test file parses and contains only the function.
        foreach ($file in Get-ChildItem -Path $paths.TestPath -Filter 'Test.EIDSCA.*.ps1') {
            $errors = $null
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref] $null, [ref] $errors)
            $errors | Should -BeNullOrEmpty
            $ast.EndBlock.Statements.Count | Should -Be 1
        }

        # The value functions no longer skip; the native tests do.
        Get-Content -Path (Join-Path $paths.PowerShellFunctionsPath 'Test-MtEidscaZZ97.ps1') -Raw | Should -Not -Match 'SkippedBecause'
    }

    It 'committed EIDSCA files match what the generator produces (drift check)' {
        # Rerun the generator offline (local EIDSCA config and page title cache) into a temporary folder.
        # The value functions and the dispatcher share one folder, as in powershell/internal/generated/eidsca.
        $root = Join-Path $TestDrive 'drift'
        $paths = New-GeneratorOutput -Root $root
        $pwsh = (Get-Process -Id $PID).Path
        $output = & $pwsh -NoProfile -NonInteractive -File $script:EidscaBuildScript `
            -TestPath $paths.TestPath -PowerShellFunctionsPath $paths.PowerShellFunctionsPath `
            -PublicFunctionPath $paths.PowerShellFunctionsPath 3>&1 2>&1
        $LASTEXITCODE | Should -Be 0 -Because ($output | Out-String)
        $output | Where-Object { "$_" -like '*No cached page title*' } | Should -BeNullOrEmpty -Because 'every page title must be in build/eidsca/PageTitles.json'

        $pairs = @(
            @{ Fresh = $paths.TestPath; Committed = Join-Path $script:RepoRoot 'tests/eidsca'; Filter = 'Test.EIDSCA.*' }
            @{ Fresh = $paths.PowerShellFunctionsPath; Committed = Join-Path $script:RepoRoot 'powershell/internal/generated/eidsca'; Filter = 'Test-MtEidsca*' }
        )
        $problems = foreach ($pair in $pairs) {
            $fresh = @(Get-ChildItem -Path $pair.Fresh -Filter $pair.Filter -File | ForEach-Object Name)
            $committed = @(Get-ChildItem -Path $pair.Committed -Filter $pair.Filter -File | ForEach-Object Name)
            foreach ($name in $committed | Where-Object { $_ -notin $fresh }) { "$($pair.Committed)/${name}: not generated any more" }
            foreach ($name in $fresh | Where-Object { $_ -notin $committed }) { "$($pair.Committed)/${name}: missing" }
            foreach ($name in $fresh | Where-Object { $_ -in $committed }) {
                if ((Get-NormalizedContent (Join-Path $pair.Fresh $name)) -ne (Get-NormalizedContent (Join-Path $pair.Committed $name))) {
                    "$($pair.Committed)/${name}: differs"
                }
            }
        }
        Join-Path $script:RepoRoot 'tests/eidsca/Test-EIDSCA.Generated.Tests.ps1' | Should -Not -Exist
        $problems | Should -BeNullOrEmpty -Because (
            'generated EIDSCA files must not be edited by hand. Run ./build/eidsca/Update-EidscaTests.ps1 and commit the result: ' +
            ($problems -join '; '))
    }

    It 'reproduces the 2.x Block, selection tags and title of every EIDSCA check' {
        $module = Import-Module (Join-Path $script:RepoRoot 'powershell/Maester.psd1') -Force -PassThru -WarningAction SilentlyContinue |
            Where-Object Name -EQ 'Maester' | Select-Object -First 1
        $tests = @(& $module { param($p) Get-MtTest -Path $p } (Join-Path $script:RepoRoot 'tests/eidsca'))
        $golden = @((Get-Content -Path (Join-Path $script:RepoRoot 'powershell/tests/fixtures/golden/tags-and-blocks.json') -Raw |
                    ConvertFrom-Json).Entries | Where-Object { $_.Id -like 'EIDSCA.*' })
        $golden.Count | Should -BeGreaterThan 0
        $tests.Count | Should -Be $golden.Count

        $problems = foreach ($entry in $golden) {
            $test = $tests | Where-Object Id -EQ $entry.Id
            if (-not $test) { "$($entry.Id): missing"; continue }
            if (-not $test.IsValid) { "$($entry.Id): invalid ($($test.Errors -join '; '))" }
            if ($test.Format -ne 'Native') { "$($entry.Id): not native" }
            if ($test.Category -ne $entry.Block) { "$($entry.Id): Category '$($test.Category)' is not the 2.x Block '$($entry.Block)'" }
            $was = @($entry.SelectionTags | Sort-Object -Unique) -join ','
            $is = @($test.EffectiveTag | Sort-Object -Unique) -join ','
            if ($was -ne $is) { "$($entry.Id): tags '$is' are not the 2.x selection tags '$was'" }
            $title = (($entry.Name -split ': ', 2)[1]) -replace ' See https://\S+$', ''
            if ($test.Title -ne $title) { "$($entry.Id): title '$($test.Title)' is not '$title'" }
            if (-not $test.Author) { "$($entry.Id): no Author" }
        }
        $problems | Should -BeNullOrEmpty -Because ($problems -join '; ')
    }
}
