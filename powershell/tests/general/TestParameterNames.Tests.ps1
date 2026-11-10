# The mechanical half of the parameter naming rules ("Parameter names" in website/docs/writing-tests/attribute-rubric.md): every
# parameter of a built-in test or a pack that ships with Maester follows one convention, so an admin who
# sets a value in TestSettings can guess its name. Whether a name says what it measures is a judgement; the
# attribute-review workflow and the reviewer check that. Custom tests are not checked here.

BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force -WarningAction SilentlyContinue
    $script:repoRoot = (Resolve-Path "$PSScriptRoot/../../..").Path

    $files = @(Get-ChildItem -Path (Join-Path $script:repoRoot 'tests'), (Join-Path $script:repoRoot 'packs') -Recurse -File -Filter 'Test.*.ps1' |
            Where-Object { $_.FullName -notmatch '[\\/]custom[\\/]' })
    $script:files = $files
    $tests = @(InModuleScope Maester -Parameters @{ Files = $files.FullName } {
            foreach ($file in $Files) { [pscustomobject](Read-MtNativeTest -Path $file -BuiltIn) }
        })
    $script:parameters = @(foreach ($t in $tests) {
            foreach ($p in @($t.Parameters | Where-Object { -not $_.EngineOwned })) {
                [pscustomobject]@{ Id = $t.Id; Name = $p.Name; Type = $p.Type; Setting = $p.Setting }
            }
        })
    $script:settings = InModuleScope Maester { (Get-MtSettingRegistry).Settings }

    # Reports offenders as "ID: Name - detail" so a failure names every parameter to rename.
    function Get-Offender {
        param([scriptblock] $Where, [scriptblock] $Detail)
        @($script:parameters | Where-Object $Where | ForEach-Object { "$($_.Id): $($_.Name) - $(& $Detail $_)" } | Sort-Object -Unique)
    }
}

Describe 'Names of test parameters' {
    It 'Finds the parameters of the built-in tests' {
        $script:parameters.Count | Should -BeGreaterThan 100
    }

    It 'Uses PascalCase' {
        $offenders = Get-Offender { $_.Name -cnotmatch '^[A-Z][A-Za-z0-9]*$' } { 'start with a capital letter and use letters and digits only' }
        $offenders | Should -BeNullOrEmpty -Because 'parameter names are PascalCase, like PowerShell parameters'
    }

    It 'Spells out Maximum and Minimum' {
        $offenders = Get-Offender { $_.Name -cmatch '^(Max|Min)(?!imum)' } {
            param($p) "rename to $($p.Name -creplace '^Max(?!imum)', 'Maximum' -creplace '^Min(?!imum)', 'Minimum')"
        }
        $offenders | Should -BeNullOrEmpty -Because 'a limit is named Maximum<What><Unit> or Minimum<What><Unit>, never Max or Min'
    }

    It 'Ends a unit with a plain suffix' {
        $offenders = Get-Offender { $_.Name -cmatch 'In(Days|Hours|Minutes|Seconds)$' } {
            param($p) "rename to $($p.Name -creplace 'In(Days|Hours|Minutes|Seconds)$', '$1')"
        }
        $offenders | Should -BeNullOrEmpty -Because 'a unit is a plain suffix: MaximumLifetimeDays, not MaximumLifetimeInDays'
    }

    It 'Names a list in the plural' {
        $offenders = Get-Offender { $_.Type -in 'string[]', 'object[]' -and $_.Name -cnotmatch 's$' } { 'a list takes a plural name, for example ParkedDomains' }
        $offenders | Should -BeNullOrEmpty -Because 'a string[] or object[] parameter holds several values, so its name is plural'
    }

    It 'Avoids the names of PowerShell common parameters' {
        $reserved = 'Force', 'Confirm', 'WhatIf', 'PassThru'
        $offenders = Get-Offender { $_.Name -in $reserved } { 'name what turning it on does, for example AllDomains' }
        $offenders | Should -BeNullOrEmpty -Because 'these names mean something else in PowerShell'
    }

    It 'Gives one name one type' {
        $offenders = @($script:parameters | Group-Object Name | Where-Object { @($_.Group.Type | Sort-Object -Unique).Count -gt 1 } | ForEach-Object {
                "$($_.Name): $(($_.Group | ForEach-Object { "$($_.Id) ($($_.Type))" }) -join ', ')"
            })
        $offenders | Should -BeNullOrEmpty -Because 'a name that holds a number on one test and a list on another means two different things; rename one'
    }

    It 'Binds one name to one setting' {
        # A test may give a bound name a value of its own, but two tests that share a name and bind it must bind the same setting.
        $offenders = @($script:parameters | Where-Object Setting | Group-Object Name | Where-Object { @($_.Group.Setting | Sort-Object -Unique).Count -gt 1 } | ForEach-Object {
                "$($_.Name): $(($_.Group | ForEach-Object { "$($_.Id) ($($_.Setting))" }) -join ', ')"
            })
        $offenders | Should -BeNullOrEmpty -Because 'one parameter name has one meaning wherever it is bound'
    }
}

Describe 'Settings that tests receive as parameters' {
    It 'Binds only registered settings or a pack''s own Namespace.Key settings' {
        $offenders = Get-Offender { $_.Setting -and -not $script:settings.ContainsKey($_.Setting) -and $_.Setting -notmatch '\.' } { "'$($_.Setting)' is not in assets/MaesterSettings.psd1" }
        $offenders | Should -BeNullOrEmpty
    }

    It 'Leaves a bound setting to the engine instead of reading it in the test' {
        # A test that calls Get-MtSetting for a setting other tests receive as a parameter hides the value from
        # Get-MtTest and the results, and a TestSettings row cannot override it.
        $bound = @($script:parameters | Where-Object Setting | ForEach-Object Setting | Sort-Object -Unique)
        $offenders = foreach ($file in $script:files) {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$null, [ref]$null)
            $testFunctions = $ast.FindAll({
                    param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
                    $node.Body.ParamBlock -and ($node.Body.ParamBlock.Attributes.TypeName.Name -match '^MaesterTest(Attribute)?$')
                }, $false)
            foreach ($function in $testFunctions) {
                $calls = $function.Body.FindAll({
                        param($node) $node -is [System.Management.Automation.Language.CommandAst] -and $node.GetCommandName() -in 'Get-MtSetting', 'Get-MtMaesterConfigGlobalSetting'
                    }, $true)
                foreach ($call in $calls) {
                    $name = @($call.CommandElements | Where-Object { $_ -is [System.Management.Automation.Language.StringConstantExpressionAst] -and $_.Value -ne $call.GetCommandName() } | ForEach-Object Value) | Select-Object -First 1
                    if ($name -and $name -in $bound) { "$($file.Name): reads '$name' with Get-MtSetting; declare [MaesterParameter(Setting = '$name')] instead" }
                }
            }
        }
        @($offenders) | Should -BeNullOrEmpty
    }
}
