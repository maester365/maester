BeforeAll {
    $script:RepoRoot = (Resolve-Path "$PSScriptRoot/../../..").Path
    $script:EidscaBuildScript = Join-Path $script:RepoRoot 'build/eidsca/Update-EidscaTests.ps1'
}

Describe 'EIDSCA generator' {
    It 'does not manage generated website test documentation' {
        $scriptContent = Get-Content -Path $script:EidscaBuildScript -Raw

        $scriptContent | Should -Not -Match 'DocsPath'
        $scriptContent | Should -Not -Match 'website[/\\]docs[/\\]tests'
    }

    It 'generates canonical sources from fixture input' {
        $internalPath = Join-Path $TestDrive 'internal'
        $publicPath = Join-Path $TestDrive 'public'
        $testFilePath = Join-Path $TestDrive 'Test-EIDSCA.Generated.Tests.ps1'
        $null = New-Item -Path $internalPath -ItemType Directory
        $null = New-Item -Path $publicPath -ItemType Directory

        Copy-Item -Path (Join-Path $script:RepoRoot 'powershell/internal/eidsca/@templateps1.txt') -Destination $internalPath
        Copy-Item -Path (Join-Path $script:RepoRoot 'powershell/internal/eidsca/@template.md') -Destination $internalPath
        Copy-Item -Path (Join-Path $script:RepoRoot 'powershell/public/eidsca/@Test-MtEidscaControl.txt') -Destination $publicPath

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
            "RecommendedValue": "true",
            "DefaultValue": "false",
            "CurrentValue": "isEnabled",
            "Recommendation": "",
            "PortalDeepLink": "",
            "HowToFix": "   ",
            "MitreTactic": [],
            "MitreTechnique": [],
            "MitreMitigation": [],
            "SkipCondition": "",
            "SkipReason": ""
          },
          {
            "CheckId": "EIDSCA.ZZ97",
            "Name": "BlankRemediation",
            "DisplayName": "Blank remediation",
            "Description": "Blank remediation description",
            "Severity": "Medium",
            "RecommendedValue": "true",
            "DefaultValue": "false",
            "CurrentValue": "isEnabled",
            "Recommendation": "",
            "PortalDeepLink": "",
            "HowToFix": "",
            "MitreTactic": [],
            "MitreTechnique": [],
            "MitreMitigation": [],
            "SkipCondition": "",
            "SkipReason": ""
          }
        ]
      }
    ]
  }
]
'@
        Mock Invoke-WebRequest { $fixtureJson } -ParameterFilter { $Uri -eq 'https://fixture.invalid/EidscaConfig.json' }

        & $script:EidscaBuildScript `
            -TestFilePath $testFilePath `
            -PowerShellFunctionsPath $internalPath `
            -PublicFunctionPath $publicPath `
            -AadSecConfigUrl 'https://fixture.invalid/EidscaConfig.json'

        Join-Path $internalPath 'Test-MtEidscaZZ99.ps1' | Should -Exist
        $remediationMarkdownPath = Join-Path $internalPath 'Test-MtEidscaZZ99.md'
        $remediationMarkdownPath | Should -Exist
        Join-Path $publicPath 'Test-MtEidscaControl.ps1' | Should -Exist
        $testFilePath | Should -Exist
        Get-Content -Path $testFilePath -Raw | Should -Match 'EIDSCA\.ZZ99'

        $expectedRemediation = @'
#### Remediation action

Use [the portal](https://example.invalid) or run: ```$literal $$ $& $1```
'@
        $expectedRemediation = $expectedRemediation.Trim() -replace '\r\n?', "`n"
        $remediationMarkdown = Get-Content -Path $remediationMarkdownPath -Raw
        $remediationMarkdown = $remediationMarkdown -replace '\r\n?', "`n"
        $remediationMarkdown.Contains($expectedRemediation) | Should -BeTrue
        Get-Content -Path (Join-Path $internalPath 'Test-MtEidscaZZ98.md') -Raw | Should -Not -Match 'Remediation action'
        Get-Content -Path (Join-Path $internalPath 'Test-MtEidscaZZ97.md') -Raw | Should -Not -Match 'Remediation action'
        Should -Invoke Invoke-WebRequest -Times 1 -Exactly
    }
}
