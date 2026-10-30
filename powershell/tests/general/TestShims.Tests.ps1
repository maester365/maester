# A shim is a built-in test whose body is one return of another built-in test's function: a benchmark test for a
# requirement that another suite already checks (website/docs/writing-tests/index.mdx, "Tests that another suite
# already has"). These tests find every shim and check that it is the same check as the test it calls, so the two
# cannot drift apart without a failure here.

BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force -WarningAction SilentlyContinue
    $script:repoRoot = (Resolve-Path "$PSScriptRoot/../../..").Path

    $files = @(Get-ChildItem -Path (Join-Path $script:repoRoot 'tests') -Recurse -File -Filter 'Test.*.ps1' |
            Where-Object { $_.FullName -notmatch '[\\/]custom[\\/]' })
    $script:tests = @(InModuleScope Maester -Parameters @{ Files = $files.FullName } {
            foreach ($file in $Files) { [pscustomobject](Read-MtNativeTest -Path $file -BuiltIn) }
        })
    $byFunction = @{}
    foreach ($test in $script:tests) { if ($test.FunctionName) { $byFunction[$test.FunctionName] = $test } }

    # Tests whose body is a single return statement whose pipeline is one Test-Mt* command. The command is
    # another built-in test's function (a shim) or a shared check of the suite (CIS.M365.9.1.x).
    $script:singleCalls = @(foreach ($test in $script:tests) {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($test.File, [ref]$null, [ref]$null)
            $function = $ast.Find({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $test.FunctionName }, $true)
            if (-not $function -or $function.Body.BeginBlock -or $function.Body.ProcessBlock) { continue }
            $statements = @($function.Body.EndBlock.Statements)
            if ($statements.Count -ne 1 -or $statements[0] -isnot [System.Management.Automation.Language.ReturnStatementAst]) { continue }
            $pipeline = $statements[0].Pipeline
            if ($pipeline -isnot [System.Management.Automation.Language.PipelineAst] -or $pipeline.PipelineElements.Count -ne 1) { continue }
            $command = $pipeline.PipelineElements[0]
            if ($command -isnot [System.Management.Automation.Language.CommandAst] -or $command.GetCommandName() -notlike 'Test-Mt*') { continue }
            [pscustomobject]@{
                Test       = $test
                Command    = $command.GetCommandName()
                Target     = $byFunction[$command.GetCommandName()]
                Parameters = @($command.CommandElements | Where-Object { $_ -is [System.Management.Automation.Language.CommandParameterAst] } | ForEach-Object ParameterName)
            }
        })
    $script:shims = @($script:singleCalls | Where-Object Target)

    # The attributes that say what a check is about, how urgent it is and where it runs. A shim declares the
    # same values as the test it calls; its own are Id, Title, Control, Author and Contributor.
    $script:sameAttributes = @('Product', 'RelatedProduct', 'Feature', 'Area', 'ResourceType', 'Severity', 'UserImpact',
        'ImplementationCost', 'Mitre', 'Service', 'License', 'Permission', 'TenantType', 'Cloud', 'Platform', 'Lifecycle',
        'LongRunning', 'Exclusive')
}

Describe 'Built-in tests that call another suite''s test' {
    It 'Finds the shims' {
        @($script:shims.Test.Id) | Should -Contain 'ASD.ISM-1504'
    }

    It 'Calls a function that exists' {
        # A shim whose test was renamed or removed would otherwise fail only when it runs.
        $missing = @(InModuleScope Maester -Parameters @{ Commands = @($script:singleCalls.Command | Sort-Object -Unique) } {
                $Commands | Where-Object { -not (Get-Command -Name $_ -CommandType Function -ErrorAction Ignore) }
            })
        @($script:singleCalls | Where-Object Command -In $missing | ForEach-Object { "$($_.Test.Id): $($_.Command)" }) | Should -BeNullOrEmpty
    }

    It 'Calls a test that is not a shim itself' {
        $shimIds = @($script:shims.Test.Id)
        @($script:shims | Where-Object { $_.Target.Id -in $shimIds } | ForEach-Object { "$($_.Test.Id): $($_.Target.Id)" }) | Should -BeNullOrEmpty
    }

    It 'Declares the attributes of the test it calls' {
        $offenders = foreach ($shim in $script:shims) {
            foreach ($name in $script:sameAttributes) {
                $own = @($shim.Test.$name | Where-Object { $null -ne $_ -and "$_" -ne '' }) -join ', '
                $theirs = @($shim.Target.$name | Where-Object { $null -ne $_ -and "$_" -ne '' }) -join ', '
                if ($own -cne $theirs) { "$($shim.Test.Id) $name '$own', $($shim.Target.Id) '$theirs'" }
            }
        }
        @($offenders) | Should -BeNullOrEmpty
    }

    It 'Passes only parameters the test it calls declares' {
        $offenders = foreach ($shim in $script:shims) {
            $declared = @($shim.Target.Parameters.Name)
            foreach ($name in $shim.Parameters) { if ($name -notin $declared) { "$($shim.Test.Id): -$name" } }
        }
        @($offenders) | Should -BeNullOrEmpty
    }

    It 'Leaves its own requirement off the test it calls' {
        # The requirement a shim implements, its first Control, is claimed once, by the shim, so a run does not
        # report it twice. Supporting controls such as NIST SP 800-53 may be on both.
        $offenders = foreach ($shim in $script:shims) {
            $requirement = @($shim.Test.Control)[0]
            if ($requirement -and $requirement -in @($shim.Target.Control)) { "$($shim.Target.Id): $requirement" }
        }
        @($offenders) | Should -BeNullOrEmpty
    }

    It 'Names the test it calls in its guide' {
        $offenders = foreach ($shim in $script:shims) {
            if (-not $shim.Test.MarkdownPath -or (Get-Content -Path $shim.Test.MarkdownPath -Raw) -notmatch [regex]::Escape($shim.Target.Id)) { $shim.Test.Id }
        }
        @($offenders) | Should -BeNullOrEmpty
    }
}
