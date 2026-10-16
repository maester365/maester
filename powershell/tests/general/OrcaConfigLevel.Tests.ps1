# ORCA226/227 (and the other multi-policy checks) call SetResult with
# [ORCAConfigLevel]::Informational. Without that enum member the argument is null
# and the check crashes. https://github.com/maester365/maester/issues/2101
BeforeAll {
    $script:RepoRoot = (Resolve-Path "$PSScriptRoot/../../..").Path
    $script:OrcaClass = Join-Path $script:RepoRoot 'powershell/internal/generated/orca/orcaClass.psm1'
    $generator = Join-Path $script:RepoRoot 'build/orca/Update-OrcaTests.ps1'

    $ast = [System.Management.Automation.Language.Parser]::ParseFile($generator, [ref] $null, [ref] $null)
    $definition = $ast.Find({
            param($node)
            $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
            $node.Name -eq 'Add-OrcaConfigLevelInformational'
        }, $true)
    if ($null -eq $definition) { throw 'Add-OrcaConfigLevelInformational was not found in Update-OrcaTests.ps1.' }
    . ([scriptblock]::Create($definition.Extent.Text))
}

Describe 'ORCAConfigLevel Informational' {
    It 'is a real member and SetResult accepts the value the checks pass' {
        $runner = Join-Path $TestDrive 'orca-config-level.ps1'
        @'
using module '{0}'
$ErrorActionPreference = 'Stop'
if ($null -eq [ORCAConfigLevel]::Informational) {{ throw 'ORCAConfigLevel.Informational is null' }}

$informational = [ORCACheckConfig]::new()
$informational.SetResult([ORCAConfigLevel]::Informational, 'Fail')
if ($informational.Level -ne [ORCAConfigLevel]::Informational) {{
    throw "SetResult left Level=$($informational.Level)"
}}

$scored = [ORCACheckConfig]::new()
$scored.SetResult([ORCAConfigLevel]::Standard, 'Pass')
if ($scored.ResultStandard -ne [ORCAResult]::Pass) {{
    throw "Standard SetResult left ResultStandard=$($scored.ResultStandard)"
}}

$check = [ORCACheck]::new()
$check.AssessmentLevel = [ORCAConfigLevel]::Standard
$check.AddConfig($scored)
$check.AddConfig($informational)
if ($check.ResultStandard -ne [ORCAResult]::Pass) {{
    throw "A passing policy plus an informational one returned $($check.ResultStandard)"
}}
'@ -f ($script:OrcaClass.Replace('\', '/')) | Set-Content -LiteralPath $runner -Encoding utf8

        $pwsh = (Get-Process -Id $PID).Path
        $output = & $pwsh -NoProfile -NonInteractive -File $runner 2>&1
        $LASTEXITCODE | Should -Be 0 -Because ($output | Out-String)
    }

    It 'is reapplied by the ORCA generator when the class is regenerated' {
        $committed = [System.IO.File]::ReadAllText($script:OrcaClass)
        Add-OrcaConfigLevelInformational -Content $committed | Should -Be $committed

        $upstream = @'
enum ORCAConfigLevel
{
    None = 0
    Standard = 5
    Strict = 10
    TooStrict = 15
    All = 100
}
        } else {
            ($this.Results | Where-Object {$_.Level -eq $Level}).Value = $InputResult
        }
'@
        $once = Add-OrcaConfigLevelInformational -Content $upstream
        $once | Should -Match 'Informational = 20'
        $once | Should -Match 'foreach\(\$r in @\(\$this\.Results \| Where-Object \{\$_\.Level -eq \$Level\}\)\)'
        $once | Should -Not -Match '\(\$this\.Results \| Where-Object \{\$_\.Level -eq \$Level\}\)\.Value'
        Add-OrcaConfigLevelInformational -Content $once | Should -Be $once

        # A Windows clone of upstream ORCA has CRLF line endings.
        $crlf = $upstream -replace '\r?\n', "`r`n"
        $onceCrlf = Add-OrcaConfigLevelInformational -Content $crlf
        $onceCrlf | Should -Match 'Informational = 20'
        $onceCrlf | Should -Match 'foreach\(\$r in @\(\$this\.Results \| Where-Object \{\$_\.Level -eq \$Level\}\)\)'
        $onceCrlf | Should -Not -Match '\(\$this\.Results \| Where-Object \{\$_\.Level -eq \$Level\}\)\.Value'
        $onceCrlf | Should -Not -Match '(?<!\r)\n'
        Add-OrcaConfigLevelInformational -Content $onceCrlf | Should -Be $onceCrlf
    }

    It 'fails when upstream SetResult no longer has the line it repairs' {
        $changed = @'
enum ORCAConfigLevel
{
    None = 0
    Informational = 20
    All = 100
}
            $this.SetLevelResult($Level, $InputResult)
'@
        { Add-OrcaConfigLevelInformational -Content $changed } | Should -Throw '*upstream ORCA may have changed*'
    }
}
