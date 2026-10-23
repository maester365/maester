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
        '{ "TestSettings": [ { "Id": "EIDSCA.ZZ99", "Severity": "Critical", "RelatedProduct": ["exchange"], "Feature": "authentication-methods", "Area": "authentication", "ResourceType": "Tenant", "UserImpact": "Medium", "ImplementationCost": "Low", "Mitre": ["T1110", "T1078.004"] }, { "Id": "EIDSCA.ZZ97", "Feature": "authentication-methods", "Area": "authentication", "ResourceType": "Tenant", "UserImpact": "Low", "ImplementationCost": "Low", "Mitre": ["None"] } ] }' | Set-Content -Path $maesterConfigPath
        Mock Invoke-WebRequest { throw 'The generator must not use the network without -Download.' }

        $warnings = & $script:EidscaBuildScript @paths `
            -ConfigPath $configPath `
            -PageTitleCachePath (Join-Path $TestDrive 'PageTitles.json') `
            -MaesterConfigPath $maesterConfigPath `
            -AuthorshipPath $seedPath 3>&1

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
        # Severity comes from the EIDSCA config, not from the metadata row.
        $native | Should -Match "Severity = 'Medium'"
        $native | Should -Match "Product = 'entra'"
        $native | Should -Not -Match '(?m)^\s+(Category|Tag|Preview) = '
        $native | Should -Match "Service = 'Graph'"
        # The classification values of the metadata row, in the order of the attribute.
        $attribute = [System.Management.Automation.Language.Parser]::ParseInput($native, [ref] $null, [ref] $null).Find({
                param($n) $n -is [System.Management.Automation.Language.AttributeAst] -and $n.TypeName.Name -eq 'MaesterTest' }, $true)
        ($attribute.NamedArguments.ArgumentName -join ',') | Should -Be 'Id,Title,Product,RelatedProduct,Feature,Area,ResourceType,Severity,UserImpact,ImplementationCost,Mitre,Service,Author,Contributor'
        $native | Should -Match "RelatedProduct = 'exchange'"
        $native | Should -Match "Feature = 'authentication-methods'"
        $native | Should -Match "Area = 'authentication'"
        $native | Should -Match "ResourceType = 'Tenant'"
        $native | Should -Match "UserImpact = 'Medium'"
        $native | Should -Match "ImplementationCost = 'Low'"
        $native | Should -Match "Mitre = \('T1110', 'T1078\.004'\)"
        $native | Should -Match "Author = 'fixture-author'"
        $native | Should -Match "Contributor = 'fixture-contributor'"
        $native | Should -Not -Match 'HelpUrl'
        $native | Should -Match "return \(\`$tenantValue -eq 'true'\)"

        # A licence skip becomes License.
        $licensed = Get-Content -Path (Join-Path $paths.TestPath 'Test.EIDSCA.ZZ98.ps1') -Raw
        $licensed | Should -Match "License = 'AAD_PREMIUM'"
        $licensed | Should -Match "Severity = 'Medium'"
        # A control without a metadata row gets no classification value beyond the product, and a warning.
        @($warnings | Where-Object { "$_" -like '*EIDSCA.ZZ98 has no row*' }).Count | Should -Be 1
        @($warnings | Where-Object { "$_" -like '*EIDSCA.ZZ9[79] has no row*' }) | Should -BeNullOrEmpty
        $licensed | Should -Not -Match '(?m)^\s+(RelatedProduct|Feature|Area|ResourceType|UserImpact|ImplementationCost|Mitre) = '
        $licensed | Should -Match "Author = 'Cloud-Architekt'"
        $licensed | Should -Not -Match 'EntraIDPlan'
        $licensed | Should -Match 'return \(\$tenantValue -ge 30\)'

        # Other skips stay in the test, read their discovery variable, and never call another test.
        $skipped = Get-Content -Path (Join-Path $paths.TestPath 'Test.EIDSCA.ZZ97.ps1') -Raw
        $skipped | Should -Match "Severity = 'Info'"
        # An Info test has no UserImpact or ImplementationCost, even when its metadata row has them.
        $skipped | Should -Not -Match '(?m)^\s+(UserImpact|ImplementationCost) = '
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

    # The title is not compared: it comes from the EIDSCA config, which may rename a check.
    It 'keeps the 2.x selection tags of every EIDSCA check, as an Entra ID test without tags' {
        $module = Import-Module (Join-Path $script:RepoRoot 'powershell/Maester.psd1') -Force -PassThru -WarningAction SilentlyContinue |
            Where-Object Name -EQ 'Maester' | Select-Object -First 1
        # The catalog, so that the tests are read as built-in tests (a custom test has no 2.x tags).
        $tests = @(& $module { Get-MtTestCatalog -Refresh | Where-Object Suite -EQ 'EIDSCA' })
        $golden = @((Get-Content -Path (Join-Path $script:RepoRoot 'powershell/tests/fixtures/golden/tags-and-blocks.json') -Raw |
                    ConvertFrom-Json).Entries | Where-Object { $_.Id -like 'EIDSCA.*' })
        $golden.Count | Should -BeGreaterThan 0
        # Checks added upstream after 2.x are not in the snapshot; every 2.x check must still be there.
        $tests.Count | Should -BeGreaterOrEqual $golden.Count

        $problems = foreach ($entry in $golden) {
            $test = $tests | Where-Object Id -EQ $entry.Id
            if (-not $test) { "$($entry.Id): missing"; continue }
            if ($test.Errors.Count -gt 0) { "$($entry.Id): invalid ($($test.Errors.Message -join '; '))" }
            if ($test.Format -ne 'Native') { "$($entry.Id): not native" }
            if ($test.Product -cne 'entra') { "$($entry.Id): Product '$($test.Product)' is not entra" }
            if ($test.Block -ne 'Entra ID') { "$($entry.Id): Block '$($test.Block)' is not the product name" }
            if (@($test.Tag).Count -gt 0) { "$($entry.Id): carries the tags $($test.Tag -join ', ')" }
            # Every 2.x tag still selects the test: its ID, and EIDSCA through the legacy tag table.
            $selection = & $module { param($t) Get-MtSelectionTag -Test $t } $test
            $was = @($entry.SelectionTags | Sort-Object -Unique) -join ','
            $is = @(@($selection.Own) + @($selection.Legacy) | Sort-Object -Unique) -join ','
            if ($was -ne $is) { "$($entry.Id): the selection tags '$is' are not the 2.x selection tags '$was'" }
            if (-not $test.Author) { "$($entry.Id): no Author" }
        }
        $problems | Should -BeNullOrEmpty -Because ($problems -join '; ')
    }
}
