BeforeAll {
    # Load only the engine DLL so these tests also run on a machine without Maester's dependencies
    # (the build-engine workflow runs them on every OS straight after checkout).
    Import-Module "$PSScriptRoot/../../../lib/Maester.Engine.dll" -Force

    $script:fixtureModule = New-Module -Name MtEngineFixture -ScriptBlock {
        $script:privateValue = 'module-private'
        function Get-PrivateValue { $script:privateValue }

        function Test-ReturnValue { [CmdletBinding()] param([object[]] $Value) foreach ($v in $Value) { $v } }
        function Test-ReturnNothing { [CmdletBinding()] param() }
        function Test-Throw { [CmdletBinding()] param() throw 'boom' }
        function Test-StatementTerminating { [CmdletBinding()] param() $x = $null; $x.Missing(); return $true }
        function Test-NonTerminating { [CmdletBinding()] param() Write-Error 'soft'; return $true }
        function Test-Skip {
            [CmdletBinding()] param()
            $record = [System.Management.Automation.ErrorRecord]::new([System.Exception]::new('not applicable'), 'MaesterTestSkipped', 'NotSpecified', $null)
            $PSCmdlet.ThrowTerminatingError($record)
        }
        function Test-SkipInsideOwnTryCatch {
            [CmdletBinding()] param()
            try {
                $record = [System.Management.Automation.ErrorRecord]::new([System.Exception]::new('inner'), 'MaesterTestSkipped', 'NotSpecified', $null)
                throw $record
            } catch {
                if ($_.FullyQualifiedErrorId -like 'MaesterTestSkipped*') { throw }
                return $false
            }
        }
        function Test-Break { [CmdletBinding()] param() break }
        function Test-Exit { [CmdletBinding()] param() exit 3 }
        function Test-Sleep { [CmdletBinding()] param() Start-Sleep -Seconds 30; $true }
        function Test-Stream {
            [CmdletBinding()] param()
            Write-Warning 'w1'
            Write-Verbose 'v1' -Verbose
            Write-Information 'i1'
            $true
        }
        function Test-Private { [CmdletBinding()] param() (Get-PrivateValue) -eq 'module-private' }
        function Test-Parameter { [CmdletBinding()] param([int] $Threshold) $Threshold -eq 5 }
        function Test-CurrentTest { [CmdletBinding()] param() [Maester.Engine.MtSession]::GetCurrentTest() }
        function Test-ErrorPreference { [CmdletBinding()] param() Write-Error 'soft'; $true }
        function Test-Attribute {
            [MaesterTest(Id = 'FIXTURE.1', Title = 'Attribute', Tag = 'a', LongRunning, Service = ('Graph', 'Exchange'))]
            [CmdletBinding()]
            param(
                [MaesterParameter(Kind = 'Entra.Group')]
                [string[]] $ExcludedGroups
            )
            $null -eq $ExcludedGroups
        }
        Export-ModuleMember -Function @()
    }

    function Invoke-Fixture {
        param(
            [Parameter(Mandatory)] [string] $Command,
            [hashtable] $Parameters,
            [int] $TimeoutSeconds,
            [string] $Id
        )
        $item = [Maester.Engine.MtWorkItem]@{ Id = $Id; Command = $Command; Parameters = $Parameters }
        if ($TimeoutSeconds) { $item.TimeoutSeconds = $TimeoutSeconds }
        Invoke-MtEngineRun -WorkItem $item -Module $script:fixtureModule -NoStreamReplay
    }
}

Describe 'Maester.Engine attribute types' {
    It 'Defines MaesterTestAttribute in the global namespace' {
        [MaesterTestAttribute].Namespace | Should -BeNullOrEmpty
        [MaesterParameterAttribute].Namespace | Should -BeNullOrEmpty
    }

    It 'Lets a function carrying [MaesterTest] and [MaesterParameter] be defined and invoked' {
        (Invoke-Fixture -Command 'Test-Attribute').ReturnKind | Should -Be 'True'
    }

    It 'Exposes the attribute on the function with bare flags and single strings for arrays' {
        $attr = & $script:fixtureModule { (Get-Command Test-Attribute).ScriptBlock.Attributes | Where-Object { $_ -is [MaesterTestAttribute] } }
        $attr.Id | Should -Be 'FIXTURE.1'
        $attr.LongRunning | Should -BeTrue
        $attr.Tag | Should -Be @('a')
        $attr.Service | Should -Be @('Graph', 'Exchange')
    }

    It 'Has the 17 properties of the design' {
        $expected = 'Id', 'Title', 'Severity', 'Category', 'Tag', 'Preview', 'LongRunning', 'Service', 'CompatibleLicense',
        'TenantType', 'Cloud', 'Platform', 'InstanceSource', 'Exclusive', 'Author', 'Contributor', 'HelpUrl'
        $actual = [MaesterTestAttribute].GetProperties() | Where-Object { $_.DeclaringType -eq [MaesterTestAttribute] } | ForEach-Object Name
        $actual | Sort-Object | Should -Be ($expected | Sort-Object)
    }
}

Describe 'Invoke-MtEngineRun outcomes' {
    It 'Reports <Case> as <Kind>' -ForEach @(
        @{ Case = '$true'; Value = @($true); Kind = 'True' }
        @{ Case = '$false'; Value = @($false); Kind = 'False' }
        @{ Case = '$null'; Value = @($null); Kind = 'Null' }
        @{ Case = 'a string'; Value = @('text'); Kind = 'NonBoolean' }
        @{ Case = 'two booleans'; Value = @($true, $true); Kind = 'Multiple' }
    ) {
        $r = Invoke-Fixture -Command 'Test-ReturnValue' -Parameters @{ Value = $Value }
        $r.Status | Should -Be 'Completed'
        $r.ReturnKind | Should -Be $Kind
    }

    It 'Reports a test that writes nothing as Null' {
        (Invoke-Fixture -Command 'Test-ReturnNothing').ReturnKind | Should -Be 'Null'
    }

    It 'Reports a throw as Error with the message' {
        $r = Invoke-Fixture -Command 'Test-Throw'
        $r.Status | Should -Be 'Error'
        $r.Reason | Should -Be 'boom'
        $r.TerminatingError | Should -Not -BeNullOrEmpty
    }

    It 'Ends the test on a statement-terminating error instead of continuing to return $true' {
        $r = Invoke-Fixture -Command 'Test-StatementTerminating'
        $r.Status | Should -Be 'Error'
        $r.ReturnKind | Should -Be 'None'
    }

    It 'Keeps a non-terminating error as a diagnostic and uses the return value' {
        $r = Invoke-Fixture -Command 'Test-NonTerminating'
        $r.Status | Should -Be 'Completed'
        $r.ReturnKind | Should -Be 'True'
        $r.Errors.Count | Should -Be 1
    }

    It 'Is not affected by a caller''s Stop error preference' {
        $ErrorActionPreference = 'Stop'
        $r = Invoke-Fixture -Command 'Test-ErrorPreference'
        $r.Status | Should -Be 'Completed'
        $r.ReturnKind | Should -Be 'True'
    }

    It 'Is not affected by a global Stop error preference (as the GitHub Actions pwsh shell sets)' {
        $saved = $global:ErrorActionPreference
        try {
            $global:ErrorActionPreference = 'Stop'
            $r = Invoke-Fixture -Command 'Test-ErrorPreference'
        } finally {
            $global:ErrorActionPreference = $saved
        }
        $r.Status | Should -Be 'Completed'
        $r.ReturnKind | Should -Be 'True'
    }

    It 'Reports the skip record as Skipped' {
        $r = Invoke-Fixture -Command 'Test-Skip'
        $r.Status | Should -Be 'Skipped'
        $r.Reason | Should -Be 'not applicable'
    }

    It 'Reports a skip re-thrown from the test''s own try/catch as Skipped' {
        (Invoke-Fixture -Command 'Test-SkipInsideOwnTryCatch').Status | Should -Be 'Skipped'
    }

    It 'Reports a stray break as Aborted and keeps running later items' {
        $items = @(
            [Maester.Engine.MtWorkItem]@{ Command = 'Test-Break' }
            [Maester.Engine.MtWorkItem]@{ Command = 'Test-ReturnValue'; Parameters = @{ Value = @($true) } }
        )
        $r = Invoke-MtEngineRun -WorkItem $items -Module $script:fixtureModule -NoStreamReplay
        $r[0].Status | Should -Be 'Aborted'
        $r[1].ReturnKind | Should -Be 'True'
    }

    It 'Reports exit as Aborted without ending the session' {
        (Invoke-Fixture -Command 'Test-Exit').Status | Should -Be 'Aborted'
    }

    It 'Stops a test at its deadline and reports Timeout' {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $r = Invoke-Fixture -Command 'Test-Sleep' -TimeoutSeconds 1
        $sw.Elapsed.TotalSeconds | Should -BeLessThan 10
        $r.Status | Should -Be 'Timeout'
    }

    It 'Runs the test in the module scope so private functions resolve' {
        (Invoke-Fixture -Command 'Test-Private').ReturnKind | Should -Be 'True'
    }

    It 'Splats parameters onto the test' {
        (Invoke-Fixture -Command 'Test-Parameter' -Parameters @{ Threshold = 5 }).ReturnKind | Should -Be 'True'
    }

    It 'Flags a parameter-binding error' {
        $r = Invoke-Fixture -Command 'Test-Parameter' -Parameters @{ Unknown = 5 }
        $r.Status | Should -Be 'Error'
        $r.IsParameterBindingError | Should -BeTrue
    }

    It 'Sets the current test while the test runs and clears it afterwards' {
        $r = Invoke-Fixture -Command 'Test-CurrentTest' -Id 'CURRENT.1'
        $r.ReturnValue | Should -Be 'CURRENT.1'
        [Maester.Engine.MtSession]::GetCurrentTest() | Should -BeNullOrEmpty
    }

    It 'Captures warning, verbose and information records on the result' {
        $r = Invoke-Fixture -Command 'Test-Stream'
        $r.Warnings.Message | Should -Be 'w1'
        $r.Verbose.Message | Should -Be 'v1'
        $r.Information.MessageData | Should -Contain 'i1'
    }

    It 'Replays the records on its own streams unless -NoStreamReplay is set' {
        $item = [Maester.Engine.MtWorkItem]@{ Command = 'Test-Stream' }
        $null = Invoke-MtEngineRun -WorkItem $item -Module $script:fixtureModule -WarningVariable wv -InformationVariable iv -WarningAction SilentlyContinue
        $wv.Message | Should -Be 'w1'
        $iv.MessageData | Should -Contain 'i1'
    }

    It 'Returns one result per item, in order' {
        $items = 1..5 | ForEach-Object { [Maester.Engine.MtWorkItem]@{ Id = "ITEM.$_"; Command = 'Test-ReturnNothing' } }
        $r = Invoke-MtEngineRun -WorkItem $items -Module $script:fixtureModule -NoStreamReplay
        $r.Id | Should -Be @('ITEM.1', 'ITEM.2', 'ITEM.3', 'ITEM.4', 'ITEM.5')
    }

    It 'Calls the start and finish callbacks on the pipeline thread' {
        $script:events = [System.Collections.Generic.List[string]]::new()
        $item = [Maester.Engine.MtWorkItem]@{ Id = 'CB.1'; Command = 'Test-ReturnNothing' }
        $null = Invoke-MtEngineRun -WorkItem $item -Module $script:fixtureModule -NoStreamReplay `
            -OnItemStarting { $script:events.Add("start $($args[0].Id)") } `
            -OnItemFinished { $script:events.Add("finish $($args[0].Id)") }
        $script:events | Should -Be @('start CB.1', 'finish CB.1')
    }
}

Describe 'Invoke-MtEngineRun pool lane' {
    It 'Runs pool-lane items on worker runspaces when MaxParallel is above 1' {
        $items = 1..4 | ForEach-Object {
            [Maester.Engine.MtWorkItem]@{ Id = "POOL.$_"; Command = 'Get-Random'; Lane = 'Pool' }
        }
        $r = Invoke-MtEngineRun -WorkItem $items -MaxParallel 2 -NoStreamReplay
        $r.Count | Should -Be 4
        $r.Lane | Select-Object -Unique | Should -Be 'Pool'
        $r.Status | Select-Object -Unique | Should -Be 'Completed'
        $r.ReturnKind | Select-Object -Unique | Should -Be 'NonBoolean'
    }

    It 'Keeps Exclusive items on the main lane' {
        $item = [Maester.Engine.MtWorkItem]@{ Command = 'Get-Random'; Lane = 'Pool'; Exclusive = $true }
        (Invoke-MtEngineRun -WorkItem $item -MaxParallel 2 -NoStreamReplay).Lane | Should -Be 'Main'
    }

    It 'Times out a pool item' {
        $item = [Maester.Engine.MtWorkItem]@{ Command = 'Start-Sleep'; Parameters = @{ Seconds = 30 }; Lane = 'Pool'; TimeoutSeconds = 1 }
        (Invoke-MtEngineRun -WorkItem $item -MaxParallel 2 -NoStreamReplay).Status | Should -Be 'Timeout'
    }
}
