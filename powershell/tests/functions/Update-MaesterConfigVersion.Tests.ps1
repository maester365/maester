BeforeAll {
    $script:BuildScriptPath = Resolve-Path "$PSScriptRoot/../../../build/Update-MaesterConfigVersion.ps1"

    function Write-TestConfig {
        param (
            [Parameter(Mandatory)]
            [string] $Path,

            [Parameter(Mandatory)]
            [string] $Content
        )

        $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
        $resolvedPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
        [System.IO.File]::WriteAllText($resolvedPath, $Content, $utf8NoBom)
    }
}

Describe 'Update-MaesterConfigVersion' {
    It 'updates existing ModuleVersion and ConfigVersion fields' {
        $configPath = Join-Path 'TestDrive:' 'maester-config.json'
        Write-TestConfig -Path $configPath -Content @'
{
  "ModuleVersion": "1.0.0",
  "ConfigVersion": "",
  "GlobalSettings": {
    "EmergencyAccessAccounts": []
  },
  "TestSettings": [
    {
      "Id": "MT.1001",
      "Severity": "High"
    }
  ]
}
'@

        & $script:BuildScriptPath -ConfigPath $configPath -ModuleVersion '2.3.4' -ConfigVersion '2026.05.12.1' *> $null

        $result = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
        $result.ModuleVersion | Should -Be '2.3.4'
        $result.ConfigVersion | Should -Be '2026.05.12.1'
        $result.TestSettings[0].Id | Should -Be 'MT.1001'
    }

    It 'preserves an explicitly provided empty ConfigVersion' {
        $configPath = Join-Path 'TestDrive:' 'maester-config-empty-version.json'
        Write-TestConfig -Path $configPath -Content @'
{
  "ModuleVersion": "1.0.0",
  "ConfigVersion": "2026.05.12.1",
  "GlobalSettings": {
    "EmergencyAccessAccounts": []
  },
  "TestSettings": []
}
'@

        & $script:BuildScriptPath -ConfigPath $configPath -ModuleVersion '2.3.4' -ConfigVersion '' *> $null

        $result = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
        $result.ModuleVersion | Should -Be '2.3.4'
        $result.ConfigVersion | Should -Be ''
    }

    It 'computes ConfigVersion from git commit dates in UTC when ConfigVersion is omitted' {
        $repoPath = Join-Path 'TestDrive:' 'utc-config-repo'
        $configPath = Join-Path $repoPath 'maester-config.json'
        $null = New-Item -Path $repoPath -ItemType Directory
        $repoProviderPath = (Resolve-Path -LiteralPath $repoPath).ProviderPath

        & git -C $repoProviderPath init --quiet
        & git -C $repoProviderPath config user.name 'Maester Test'
        & git -C $repoProviderPath config user.email 'maester-test@example.com'

        Write-TestConfig -Path $configPath -Content @'
{
  "ModuleVersion": "1.0.0",
  "ConfigVersion": "",
  "GlobalSettings": {
    "EmergencyAccessAccounts": []
  },
  "TestSettings": []
}
'@

        & git -C $repoProviderPath add maester-config.json
        $env:GIT_AUTHOR_DATE = '2026-01-02T02:00:00Z'
        $env:GIT_COMMITTER_DATE = '2026-01-02T02:00:00Z'
        & git -C $repoProviderPath commit --quiet -m 'Initial config'

        Write-TestConfig -Path $configPath -Content @'
{
  "ModuleVersion": "1.0.1",
  "ConfigVersion": "",
  "GlobalSettings": {
    "EmergencyAccessAccounts": []
  },
  "TestSettings": []
}
'@

        & git -C $repoProviderPath add maester-config.json
        $env:GIT_AUTHOR_DATE = '2026-01-02T03:00:00Z'
        $env:GIT_COMMITTER_DATE = '2026-01-02T03:00:00Z'
        & git -C $repoProviderPath commit --quiet -m 'Update config'
        Remove-Item Env:\GIT_AUTHOR_DATE, Env:\GIT_COMMITTER_DATE -ErrorAction SilentlyContinue

        & $script:BuildScriptPath -ConfigPath $configPath -ModuleVersion '2.3.4' *> $null

        $result = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
        $result.ModuleVersion | Should -Be '2.3.4'
        $result.ConfigVersion | Should -Be '2026.01.02.2'
    }

    It 'throws when required version field <MissingField> is missing' -ForEach @(
        @{
            MissingField = 'ModuleVersion'
            Content = @'
{
  "ConfigVersion": "",
  "GlobalSettings": {
    "EmergencyAccessAccounts": []
  },
  "TestSettings": []
}
'@
        }
        @{
            MissingField = 'ConfigVersion'
            Content = @'
{
  "ModuleVersion": "1.0.0",
  "GlobalSettings": {
    "EmergencyAccessAccounts": []
  },
  "TestSettings": []
}
'@
        }
    ) {
        $configPath = Join-Path 'TestDrive:' "maester-config-missing-$MissingField.json"
        Write-TestConfig -Path $configPath -Content $Content

        { & $script:BuildScriptPath -ConfigPath $configPath -ModuleVersion '2.3.4' -ConfigVersion '2026.05.12.1' *> $null } |
            Should -Throw -ExpectedMessage "*Required field $MissingField*"
    }
}
