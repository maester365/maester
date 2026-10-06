BeforeDiscovery {
    $repoRoot = (Resolve-Path "$PSScriptRoot/../../..").Path
    $script:NativeFiles = @(Get-ChildItem -Path (Join-Path $repoRoot 'tests') -Recurse -File -Filter 'Test.*.ps1' |
            Where-Object { $_.FullName -notmatch '[\\/]Custom[\\/]' } |
            ForEach-Object { @{ Name = $_.Name; Path = $_.FullName } })
}

BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force -WarningAction SilentlyContinue

    function Get-TestFunction {
        param([string] $Path)
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$null, [ref]$null)
        $functions = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $false))
        # The test function is the one with the [MaesterTest] attribute.
        $functions | Where-Object { $_.Body.ParamBlock -and ($_.Body.ParamBlock.Attributes | Where-Object { $_.TypeName.Name -eq 'MaesterTest' }) } | Select-Object -First 1
    }
}

# Rules for built-in native tests (design section 6): the engine checks connections and licences and turns an
# exception into an Error row, so the tests do not repeat that. Custom tests are not linted.
Describe 'Native built-in test <Name>' -ForEach $NativeFiles {
    BeforeAll {
        $script:function = Get-TestFunction -Path $Path
        $script:test = InModuleScope Maester -Parameters @{ P = $Path } { Read-MtNativeTest -Path $P }
    }

    It 'Is a valid native test' {
        $script:function | Should -Not -BeNullOrEmpty
        $script:test.Errors | Should -HaveCount 0 -Because (($script:test.Errors | ForEach-Object { "$($_.Code): $($_.Message)" }) -join '; ')
    }

    It 'Describes every parameter' {
        $missing = @($script:test.Parameters | Where-Object { -not $_.Description } | ForEach-Object { $_.Name })
        $missing | Should -BeNullOrEmpty -Because 'the run config reference and Get-MtTest show the description'
    }

    It 'Does not check its own connection' {
        $guards = @($script:function.Body.FindAll({
                    param($n)
                    $n -is [System.Management.Automation.Language.IfStatementAst] -and
                    $n.Clauses[0].Item1.Extent.Text -match '-not\s*\(?\s*Test-MtConnection\b'
                }, $true))
        $guards | Should -BeNullOrEmpty -Because 'the Service property makes the engine skip the test when the service is not connected'
    }

    It 'Does not check its own licence' {
        # Tests whose licence need is not one CompatibleLicense list for every run (a family where only some
        # instances need a premium licence) keep their own check.
        $allowed = @(
            'MT.1024' # Entra recommendations: only the premium recommendation instances need Entra ID P2.
        )
        if ($script:test.Id -in $allowed) { return }
        $text = $script:function.Body.Extent.Text
        $call = [regex]::Match($text, '\bGet-MtLicenseInformation\b')
        $skip = if ($call.Success) { [regex]::Match($text.Substring($call.Index), '-SkippedBecause\s+[''"]?NotLicensed\w*') }
        $skip.Success | Should -BeFalse -Because 'CompatibleLicense makes the engine skip the test when the tenant is not licensed; add the ID to the allow-list only when the licence need varies by instance or the result branches on the plan'
    }

    It 'Does not catch every exception only to report -SkippedBecause Error' {
        # A catch that handles a specific case (403 -> NotAuthorized, then Error otherwise) is fine.
        $catches = @($script:function.Body.FindAll({
                    param($n)
                    $n -is [System.Management.Automation.Language.CatchClauseAst] -and $n.CatchTypes.Count -eq 0 -and
                    $n.Body.Extent.Text -match '^\{\s*Add-MtTestResultDetail\s+-SkippedBecause\s+Error(\s+-SkippedError\s+\$_)?\s*;?\s*(return(\s+\$null)?)?\s*;?\s*\}$'
                }, $true))
        $catches | Should -BeNullOrEmpty -Because 'the engine reports an exception as an Error row'
    }

    It 'Does not write script or global variables' {
        $writes = @($script:function.Body.FindAll({
                    param($n)
                    $n -is [System.Management.Automation.Language.AssignmentStatementAst] -and
                    $n.Left -is [System.Management.Automation.Language.VariableExpressionAst] -and
                    $n.Left.VariablePath.DriveName -in 'script', 'global'
                }, $true) | ForEach-Object { $_.Left.Extent.Text })
        $writes | Should -BeNullOrEmpty -Because 'tests can run in parallel; keep state in the session cache helpers'
    }

    It 'Declares Platform when it uses Windows-only commands' {
        # The ActiveDirectory service probe already skips these tests where the module is missing.
        if (@($script:test.Service) -contains 'ActiveDirectory') { return }
        $windowsOnly = @($script:function.Body.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] }, $true) |
                Where-Object { $_.GetCommandName() -match '^(Get-AD(User|Group|GroupMember|Computer|Domain|DomainController|Forest|Object|OrganizationalUnit|Trust|RootDSE|ServiceAccount|DefaultDomainPasswordPolicy|FineGrainedPasswordPolicy)|Get-GPO\w*|Get-WmiObject|Get-CimInstance)$' })
        if ($windowsOnly) { @($script:test.Platform) | Should -Contain 'Windows' }
    }
}
