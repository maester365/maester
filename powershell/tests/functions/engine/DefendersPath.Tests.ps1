# The engine of the defender's path (docs/proposals/defenders-path.md, sections 6 to 12, milestone M3): the steps in
# scope, their status, readiness and rank (Get-MtResultStep), the priority it ranks by (Get-MtTestPriority), the
# measures read after the tests (Invoke-MtStepMeasure), LastKnown in the previous result, selection by -Step and
# -IncludePrerequisites, and the CSV, Markdown and console outputs.
#
# Most cases use a fixture catalogue written to TestDrive:
#
#   entra.base        no prerequisite
#   intune.policies   no prerequisite
#   intune.compliant  requires intune.policies; decided by the devices-compliant measure (95%)
#   entra.hybrid      only when hybrid-identity
#   entra.goal        requires entra.base and intune.policies, and one of intune.compliant and entra.hybrid
#   defender.other    unrelated, the step of a second goal
BeforeAll {
    Import-Module "$PSScriptRoot/../../../Maester.psd1" -Force -WarningAction SilentlyContinue

    $source = [ordered]@{ Url = 'https://learn.microsoft.com/entra/identity/example'; Note = 'Do the other step first.'; Reviewed = '2026-11-05' }
    $files = @{
        'goals.json'    = [ordered]@{ Goals = @(
                [ordered]@{ Id = 'goal-one'; Title = 'Goal one'; Summary = 'What goal one achieves.'; Step = 'entra.goal' }
                [ordered]@{ Id = 'goal-two'; Title = 'Goal two'; Summary = 'What goal two achieves.'; Step = 'defender.other' }
            )
        }
        'entra.json'    = [ordered]@{ Product = 'entra'; Steps = @(
                [ordered]@{ Id = 'entra.base'; Title = 'Base'; Summary = 'Base.'; Sources = @($source) }
                [ordered]@{ Id = 'entra.hybrid'; Title = 'Hybrid'; Summary = 'Hybrid.'; OnlyWhen = @('hybrid-identity'); Unchecked = 'No check.'; Sources = @($source) }
                [ordered]@{
                    Id = 'entra.goal'; Title = 'Goal step'; Summary = 'Goal.'; Requires = @('entra.base', 'intune.policies')
                    RequiresOneOf = @(, @('intune.compliant', 'entra.hybrid')); Rollout = @('Report-only first.'); Sources = @($source)
                }
            )
        }
        'intune.json'   = [ordered]@{ Product = 'intune'; Steps = @(
                [ordered]@{ Id = 'intune.policies'; Title = 'Policies'; Summary = 'Policies.'; Sources = @($source) }
                [ordered]@{ Id = 'intune.compliant'; Title = 'Compliant'; Summary = 'Compliant.'; Requires = @('intune.policies'); Measure = [ordered]@{ Key = 'devices-compliant'; MinimumShare = 95 }; Sources = @($source) }
            )
        }
        'defender.json' = [ordered]@{ Product = 'defender'; Steps = @([ordered]@{ Id = 'defender.other'; Title = 'Other'; Summary = 'Other.'; Sources = @($source) }) }
    }
    $folder = Join-Path $TestDrive 'steps'
    $null = New-Item -ItemType Directory -Path $folder
    foreach ($name in $files.Keys) { ConvertTo-Json -InputObject $files[$name] -Depth 10 | Set-Content -LiteralPath (Join-Path $folder $name) }
    $script:catalog = InModuleScope Maester -Parameters @{ F = $folder } { Get-MtStepCatalog -Path $F }

    # A result row.
    function New-Row {
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Test helper that returns an object.')]
        param([string] $Id, [string] $Result, [string[]] $Step, [string] $Severity = 'High', [string] $ReasonCode)
        [pscustomobject]@{
            Id = $Id; Title = "Title of $Id"; Result = $Result; ReasonCode = $(if ($ReasonCode) { $ReasonCode } else { $null }); Step = $Step; Severity = $Severity
            UserImpact = 'Low'; ImplementationCost = 'Low'; Mitre = @(); Control = @(); Benchmark = $null; ParentId = $null
        }
    }
    # Get-MtResultStep on the fixture catalogue.
    function Get-Path {
        param([object[]] $Row, [object[]] $Inventory = @(), [hashtable] $Measure = @{}, [object] $TenantContext = [pscustomobject]@{ HybridIdentity = $false }, [hashtable] $Extra = @{})
        InModuleScope Maester -Parameters @{ R = $Row; I = $Inventory; M = $Measure; T = $TenantContext; C = $script:catalog; X = $Extra } {
            Get-MtResultStep -InputObject $R -Inventory $I -Measure $M -TenantContext $T -Catalog $C @X
        }
    }
    $script:halfCompliant = @{ 'devices-compliant' = @{ Count = 50; Total = 100; Objects = @(
                [pscustomobject]@{ Type = 'Device'; Id = 'd1'; DisplayName = 'Laptop' }
                [pscustomobject]@{ Type = 'Device'; Id = 'd2'; DisplayName = 'Phone' }
            ); ReadAt = '2026-11-06T08:00:00Z'; ReasonCode = $null
        }
    }
    $script:rows = @(
        (New-Row 'T.goal' 'Failed' @('entra.goal'))
        (New-Row 'T.base' 'Passed' @('entra.base'))
        (New-Row 'T.pol' 'Failed' @('intune.policies') -Severity 'Medium')
    )
}

Describe 'Get-MtTestPriority' {
    It 'Gives the numbers of priority() in the report' -ForEach @(
        @{ Name = 'every attribute'; Row = [pscustomobject]@{ Severity = 'High'; UserImpact = 'Low'; ImplementationCost = 'Medium'; Mitre = @('T1110', 'T1078', 'None'); Control = @('a', 'b'); Benchmark = [pscustomobject]@{ Id = 'x' } }; Expected = 17.7 }
        @{ Name = 'no attributes'; Row = [pscustomobject]@{ Severity = 'Unknown' }; Expected = 11 }
        @{ Name = 'Info, hard to fix'; Row = [pscustomobject]@{ Severity = 'Info'; UserImpact = 'High'; ImplementationCost = 'High' }; Expected = 0 }
        @{ Name = 'severity from the result detail'; Row = [pscustomobject]@{ Severity = ''; ResultDetail = [pscustomobject]@{ Severity = 'Critical' } }; Expected = 19 }
        @{ Name = 'at most three techniques'; Row = [pscustomobject]@{ Severity = 'Low'; UserImpact = 'Low'; ImplementationCost = 'Low'; Mitre = @('T1', 'T2', 'T3', 'T4', 'T5') }; Expected = 10.9 }
    ) {
        $value = InModuleScope Maester -Parameters @{ R = $Row } { Get-MtTestPriority -InputObject $R }
        [math]::Round($value, 6) | Should -Be $Expected -Because $Name
    }
}

Describe 'Get-MtStepPrerequisite and Get-MtStepScope' {
    It 'Follows Requires, RequiresOneOf and RecommendedFirst down every level' {
        $found = InModuleScope Maester -Parameters @{ C = $script:catalog } { @(Get-MtStepPrerequisite -Step 'entra.goal' -Catalog $C) }
        $found | Sort-Object | Should -Be @('entra.base', 'entra.hybrid', 'intune.compliant', 'intune.policies')
    }

    It 'Scopes to the steps that rows that ran name, and their prerequisites' {
        $rows = @((New-Row 'T.1' 'Passed' @('intune.compliant')), (New-Row 'T.2' 'NotRun' @('defender.other')), (New-Row 'T.3' 'Passed' @('not.in-catalog')))
        $scope = InModuleScope Maester -Parameters @{ R = $rows; C = $script:catalog } { Get-MtStepScope -InputObject $R -Catalog $C }
        $scope.Named | Should -Be @('intune.compliant')
        $scope.Steps | Should -Be @('intune.policies', 'intune.compliant')
    }
}

Describe 'Get-MtResultStep' {
    It 'Returns nothing when no row that ran names a step' {
        Get-Path -Row @((New-Row 'T.1' 'Passed' @()), (New-Row 'T.2' 'NotRun' @('entra.base'))) | Should -BeNullOrEmpty
    }

    Context 'A run with a failed goal step, a failed prerequisite and a measure below its threshold' {
        BeforeAll {
            $inventory = @([pscustomobject]@{ Id = 'T.goal'; Step = @('entra.goal') }, [pscustomobject]@{ Id = 'T.goal2'; Step = @('entra.goal') })
            $script:path = Get-Path -Row $script:rows -Inventory $inventory -Measure $script:halfCompliant
            $script:byId = @{}
            foreach ($s in $script:path.Steps) { $script:byId[$s.Id] = $s }
        }

        It 'Lists the steps in scope and leaves the others out' {
            @($script:path.Steps.Id | Sort-Object) | Should -Be @('entra.base', 'entra.goal', 'entra.hybrid', 'intune.compliant', 'intune.policies')
        }

        It 'Works out each status' {
            $byId['entra.base'].Status | Should -Be 'Done'
            $byId['intune.policies'].Status | Should -Be 'NotDone'
            $byId['intune.compliant'].Status | Should -Be 'NotDone'
            $byId['entra.goal'].Status | Should -Be 'NotDone'
            $byId['entra.hybrid'].Status | Should -Be 'NotApplicable'
            $byId['entra.hybrid'].Reason | Should -Be 'ConditionNotMet'
        }

        It 'Blocks a step on a NotDone requirement and on a group whose applicable steps are all NotDone' {
            $byId['intune.policies'].Readiness | Should -Be 'Ready'
            $byId['intune.compliant'].Readiness | Should -Be 'Blocked'
            $byId['intune.compliant'].BlockedBy | Should -Be @('intune.policies')
            $byId['entra.goal'].Readiness | Should -Be 'Blocked'
            $byId['entra.goal'].BlockedBy | Should -Be @('intune.policies', 'intune.compliant')
            $byId['entra.base'].Readiness | Should -BeNullOrEmpty
        }

        It 'Ranks Ready first, prerequisites before their dependents, then Done and Not applicable' {
            @($script:path.Steps.Id) | Should -Be @('intune.policies', 'intune.compliant', 'entra.goal', 'entra.base', 'entra.hybrid')
            # ForEach-Object, not .Rank: an array's own Rank property (its number of dimensions) wins over member enumeration.
            @($script:path.Steps | ForEach-Object Rank) | Should -Be @(1, 2, 3, 4, 5)
            $byId['intune.policies'].Unlocks | Should -Be @('intune.compliant', 'entra.goal')
        }

        It 'Lists the tests from the inventory, with NotInRun for a test that has no row' {
            $tests = $byId['entra.goal'].Tests
            $tests.Id | Should -Be @('T.goal', 'T.goal2')
            $tests[0].Result | Should -Be 'Failed'
            $tests[1].Result | Should -Be 'NotRun'
            $tests[1].ReasonCode | Should -Be 'NotInRun'
        }

        It 'Writes the measure in the shape of the result' {
            $m = $byId['intune.compliant'].Measure
            $m.PSObject.Properties.Name | Should -Be @('Key', 'Count', 'Total', 'Share', 'MinimumShare', 'Met', 'ReadAt', 'Caveat', 'ObjectCount', 'Objects', 'ReasonCode')
            $m.Key | Should -Be 'devices-compliant'
            $m.Share | Should -Be 50
            $m.MinimumShare | Should -Be 95
            $m.Met | Should -BeFalse
            $m.ObjectCount | Should -Be 2
            $m.Objects.Id | Should -Be @('d1', 'd2')
            $m.Caveat | Should -Not -BeNullOrEmpty
            $m.ReasonCode | Should -BeNullOrEmpty
            $byId['entra.base'].Measure | Should -BeNullOrEmpty
        }

        It 'Lists the goals in scope with their progress' {
            @($script:path.Goals).Count | Should -Be 1
            $goal = $script:path.Goals[0]
            $goal.Id | Should -Be 'goal-one'
            $goal.Steps | Should -Be @('entra.base', 'intune.policies', 'intune.compliant', 'entra.hybrid', 'entra.goal')
            $goal.Applicable | Should -Be 4
            $goal.Done | Should -Be 1
            $goal.Status | Should -Be 'InProgress'
            $byId['entra.base'].Goals | Should -Be @('goal-one')
        }

        It 'Serialises to JSON with the objects of the measure intact' {
            $json = [pscustomobject]@{ Steps = $script:path.Steps } | ConvertTo-Json -Depth 5 | ConvertFrom-Json
            ($json.Steps | Where-Object Id -EQ 'intune.compliant').Measure.Objects[0].DisplayName | Should -Be 'Laptop'
            ($json.Steps | Where-Object Id -EQ 'entra.goal').RequiresOneOf[0] | Should -Be @('intune.compliant', 'entra.hybrid')
        }
    }

    It 'Meets the threshold the run config sets, and keeps at most -MaxObjects objects' {
        $path = Get-Path -Row $script:rows -Measure $script:halfCompliant -Extra @{ MinimumShare = @{ 'devices-compliant' = 40 }; MaxObjects = 1 }
        $step = $path.Steps | Where-Object Id -EQ 'intune.compliant'
        $step.Status | Should -Be 'Done'
        $step.Measure.MinimumShare | Should -Be 40
        $step.Measure.Met | Should -BeTrue
        @($step.Measure.Objects).Count | Should -Be 1
        $step.Measure.ObjectCount | Should -Be 2
    }

    It 'Is Unknown, never Not done, when a test is Investigate or a measure could not be read, and the step that needs it is Unconfirmed' {
        $rows = @((New-Row 'T.goal' 'Failed' @('entra.goal')), (New-Row 'T.base' 'Investigate' @('entra.base')), (New-Row 'T.pol' 'Passed' @('intune.policies')))
        $measure = @{ 'devices-compliant' = @{ ReasonCode = 'LicenseNotFound'; ReadAt = $null } }
        $path = Get-Path -Row $rows -Measure $measure
        $byId = @{}; foreach ($s in $path.Steps) { $byId[$s.Id] = $s }
        $byId['entra.base'].Status | Should -Be 'Unknown'
        $byId['entra.base'].Reason | Should -Be 'Investigate'
        $byId['intune.compliant'].Status | Should -Be 'Unknown'
        $byId['intune.compliant'].Reason | Should -Be 'LicenseNotFound'
        $byId['intune.compliant'].Measure.ReasonCode | Should -Be 'LicenseNotFound'
        $byId['entra.goal'].Readiness | Should -Be 'Unconfirmed'
        $byId['entra.goal'].Unconfirmed | Should -Be @('entra.base', 'intune.compliant')
        $byId['entra.goal'].BlockedBy | Should -BeNullOrEmpty
    }

    It 'Is Unknown when an OnlyWhen condition cannot be read' {
        $path = Get-Path -Row $script:rows -Measure $script:halfCompliant -TenantContext $null
        ($path.Steps | Where-Object Id -EQ 'entra.hybrid').Status | Should -Be 'Unknown'
        ($path.Steps | Where-Object Id -EQ 'entra.hybrid').Reason | Should -Be 'ConditionUnknown'
    }

    It 'Is Not applicable when every verifying test that ran was skipped as NotApplicable' {
        $path = Get-Path -Row @((New-Row 'T.base' 'Skipped' @('entra.base') -ReasonCode 'NotApplicable'))
        $path.Steps[0].Status | Should -Be 'NotApplicable'
        $path.Steps[0].Reason | Should -Be 'TestsNotApplicable'
    }

    It 'Says why a step is Not checked, and gives the Earlier status of an earlier run' {
        $inventory = @([pscustomobject]@{ Id = 'T.base'; Step = @('entra.base') })
        $lastKnown = [pscustomobject]@{ 'T.base' = [pscustomobject]@{ Result = 'Passed'; ReasonCode = $null; ExecutedAt = '2026-11-01T08:00:00.0000000+00:00'; File = 'TestResults-old.json' } }
        $path = Get-Path -Row @((New-Row 'T.goal' 'Failed' @('entra.goal'))) -Inventory $inventory -Extra @{ MeasuresDisabled = $true; LastKnown = $lastKnown }
        $byId = @{}; foreach ($s in $path.Steps) { $byId[$s.Id] = $s }
        $byId['entra.base'].Status | Should -Be 'NotChecked'
        $byId['entra.base'].Reason | Should -Be 'NotSelected'
        $byId['entra.base'].Earlier.Status | Should -Be 'Done'
        $byId['entra.base'].Earlier.File | Should -Be 'TestResults-old.json'
        $byId['intune.policies'].Reason | Should -Be 'NoCheck'
        $byId['intune.policies'].Earlier | Should -BeNullOrEmpty
        $byId['intune.compliant'].Reason | Should -Be 'MeasureOff'
        $byId['intune.compliant'].Measure.ReasonCode | Should -Be 'MeasureOff'
        $goal = $path.Goals[0]
        $goal.NotChecked | Should -Be 3
        $goal.Status | Should -Be 'NotStarted'
    }
}

Describe 'Invoke-MtStepMeasure' {
    BeforeAll {
        $registryFile = Join-Path $TestDrive 'measures.psd1'
        @"
@{ Measures = @(@{ Key = 'devices-compliant'; Function = 'Get-MtDeviceComplianceShare'; Title = 'Devices'; Unit = 'devices'; Service = 'Graph'; License = 'INTUNE_A'; Permission = 'Graph:Scope:Device.Read.All | Graph:Scope:Directory.Read.All' }) }
"@ | Set-Content -LiteralPath $registryFile
        $script:registry = InModuleScope Maester -Parameters @{ F = $registryFile } { Get-MtMeasureRegistry -Path $F }
        function New-Context {
            param([bool] $Graph = $true, [string[]] $Plans = @('INTUNE_A'), [string[]] $Scopes = @('Directory.Read.All'))
            [pscustomobject]@{
                Platform = 'Linux'; TenantType = 'Workforce'; Cloud = 'Commercial'; Services = [pscustomobject]@{ Graph = $Graph }
                Licenses = [pscustomobject]@{ State = 'Known'; ServicePlanNames = $Plans; ServicePlanIds = @(); SkuIds = @() }; Scopes = $Scopes
            }
        }
        function Read-Measure {
            param([object] $Context, [switch] $Disabled, [switch] $Throw)
            InModuleScope Maester -Parameters @{ T = $Context; D = [bool]$Disabled; E = [bool]$Throw; R = $script:rows; C = $script:catalog; G = $script:registry } {
                if ($E) { Mock Get-MtDeviceComplianceShare { throw 'Service unavailable' } }
                else { Mock Get-MtDeviceComplianceShare { [pscustomobject]@{ Count = 3; Total = 4; Objects = @([pscustomobject]@{ Type = 'Device'; Id = 'd1'; DisplayName = 'Laptop' }) } } }
                Invoke-MtStepMeasure -InputObject $R -TenantContext $T -Disabled:$D -Catalog $C -Registry $G
            }
        }
    }

    It 'Reads each measure of the steps in scope once' {
        $readings = Read-Measure (New-Context)
        @($readings.Keys) | Should -Be @('devices-compliant')
        $readings['devices-compliant'].Count | Should -Be 3
        $readings['devices-compliant'].Total | Should -Be 4
        $readings['devices-compliant'].ReasonCode | Should -BeNullOrEmpty
        $readings['devices-compliant'].ReadAt | Should -Match '^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ$'
    }

    It 'Gates a measure like a test: <Code>' -ForEach @(
        @{ Code = 'ServiceNotConnected'; Graph = $false; Plans = @('INTUNE_A'); Scopes = @('Directory.Read.All') }
        @{ Code = 'LicenseNotFound'; Graph = $true; Plans = @('AAD_PREMIUM'); Scopes = @('Directory.Read.All') }
        @{ Code = 'PermissionNotGranted'; Graph = $true; Plans = @('INTUNE_A'); Scopes = @('User.Read.All') }
    ) {
        $readings = Read-Measure (New-Context -Graph $Graph -Plans $Plans -Scopes $Scopes)
        $readings['devices-compliant'].ReasonCode | Should -Be $Code
        $readings['devices-compliant'].Count | Should -BeNullOrEmpty
    }

    It 'Accepts the ReadWrite form of a permission' {
        (Read-Measure (New-Context -Scopes @('Device.ReadWrite.All')))['devices-compliant'].ReasonCode | Should -BeNullOrEmpty
    }

    It 'Records MeasureError when the reader throws' {
        $readings = Read-Measure (New-Context) -Throw
        $readings['devices-compliant'].ReasonCode | Should -Be 'MeasureError'
        $readings['devices-compliant'].ReasonDetail | Should -BeLike '*Service unavailable*'
    }

    It 'Reads nothing when the run config turns measures off' {
        (Read-Measure (New-Context) -Disabled).Count | Should -Be 0
    }
}

Describe 'Get-MtMeasureSetting and the Measures section of the run config' {
    It 'Defaults to on, with no thresholds' {
        $setting = InModuleScope Maester { Get-MtMeasureSetting -RunConfig $null }
        $setting.Enabled | Should -BeTrue
        $setting.MinimumShare.Count | Should -Be 0
    }

    It 'Reads Enabled and MinimumShare from a resolved config' {
        $setting = InModuleScope Maester {
            $config = Resolve-MtRunConfig -Config ([pscustomobject]@{ Measures = [pscustomobject]@{ Enabled = $false; MinimumShare = [pscustomobject]@{ 'devices-compliant' = [long]80 } } })
            Get-MtMeasureSetting -RunConfig $config
        }
        $setting.Enabled | Should -BeFalse
        $setting.MinimumShare['devices-compliant'] | Should -Be 80
    }

    It 'Rejects a threshold outside 1 to 100' {
        { InModuleScope Maester { Resolve-MtRunConfig -Config ([pscustomobject]@{ Measures = [pscustomobject]@{ MinimumShare = [pscustomobject]@{ 'devices-compliant' = [long]120 } } }) } } |
            Should -Throw '*Measures.MinimumShare.devices-compliant*'
    }
}

Describe 'Get-MtPreviousResult -LastKnownId' {
    BeforeAll {
        $script:history = Join-Path $TestDrive 'history'
        $null = New-Item -ItemType Directory -Path $script:history
        $write = {
            param($name, $executedAt, $tests, $age)
            $path = Join-Path $script:history $name
            [ordered]@{ TotalCount = @($tests).Count; PassedCount = 0; ExecutedAt = $executedAt; TenantId = 't1'; Tests = @($tests) } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $path
            (Get-Item -LiteralPath $path).LastWriteTimeUtc = [datetime]::UtcNow.AddHours(-$age)
        }
        & $write 'TestResults-old.json' '2026-11-01T08:00:00Z' @(@{ Id = 'X'; Result = 'Passed' }, @{ Id = 'Y'; Result = 'Failed' }) 48
        & $write 'TestResults-new.json' '2026-11-05T08:00:00Z' @(@{ Id = 'X'; Result = 'NotRun'; ReasonCode = 'NotSelected' }, @{ Id = 'Z'; Result = 'Passed' }) 1
    }

    It 'Gives the newest earlier result that ran each test' {
        $previous = InModuleScope Maester -Parameters @{ F = $script:history } { Get-MtPreviousResult -Folder $F -TenantId 't1' -LastKnownId 'X', 'Y', 'W' }
        $previous.File | Should -Be 'TestResults-new.json'
        $previous.LastKnown.X.Result | Should -Be 'Passed'
        $previous.LastKnown.X.File | Should -Be 'TestResults-old.json'
        $previous.LastKnown.Y.Result | Should -Be 'Failed'
        $previous.LastKnown.PSObject.Properties['W'] | Should -BeNullOrEmpty
    }

    It 'Leaves LastKnown out when no ID is asked for' {
        $previous = InModuleScope Maester -Parameters @{ F = $script:history } { Get-MtPreviousResult -Folder $F -TenantId 't1' }
        $previous.PSObject.Properties['LastKnown'] | Should -BeNullOrEmpty
    }
}

Describe 'Selection by step' {
    BeforeAll {
        $script:prqFolder = Join-Path $TestDrive 'prerequisites'
        $null = New-Item -ItemType Directory -Path $script:prqFolder
        $tests = @(
            @{ Id = 'PRQ.1'; Extra = "Step = 'entra.ca-require-compliant-device'" }
            @{ Id = 'PRQ.2'; Extra = "Step = 'intune.compliance-policies', Lifecycle = 'Preview'" }
            @{ Id = 'PRQ.3'; Extra = "Step = 'defender.spf'" }
        )
        foreach ($t in $tests) {
            $name = 'Test-' + ($t.Id -replace '[^A-Za-z0-9]', '')
            @"
function $name {
    [MaesterTest(Id = '$($t.Id)', Title = 'Title of $($t.Id)', Severity = 'High', $($t.Extra))]
    [CmdletBinding()]
    param()
    `$true
}
"@ | Set-Content (Join-Path $script:prqFolder "Test.$($t.Id).ps1")
            "Description of $($t.Id).`n`n<!--- Results --->`n%TestResult%" | Set-Content (Join-Path $script:prqFolder "Test.$($t.Id).md")
        }
        # The plan rows of the fixture tests, with a second pass for -IncludePrerequisites as Invoke-Maester makes it.
        function Get-StepPlan {
            param([hashtable] $Parameters = @{})
            InModuleScope Maester -Parameters @{ P = $Parameters; F = $script:prqFolder } {
                $tests = @(Get-MtNativeTestInventory -Path $F -Root $F)
                $runConfig = Resolve-MtRunConfig -Config @{}
                $selection = Resolve-MtSelection -RunConfig $runConfig @P
                # Preview tests are left out by default, as Invoke-Maester does.
                $auto = @(if (-not $selection.IncludePreview) { 'Preview' })
                $plan = @(Resolve-MtNativePlan -Test $tests -Selection $selection -RunConfig $runConfig -AutoExcludedTag $auto -ExcludeTag $auto)
                if ($selection.IncludePrerequisites) {
                    $steps = @($plan | Where-Object { $_.Disposition -ne 'NotRun' } | ForEach-Object { $_.Test.Step } | Select-Object -Unique)
                    $plan = @(Resolve-MtNativePlan -Test $tests -Selection $selection -RunConfig $runConfig -AutoExcludedTag $auto -ExcludeTag $auto -PrerequisiteStep @(Get-MtStepPrerequisite -Step $steps))
                }
                $plan
            }
        }
    }

    It '-Step selects the tests that verify a matching step, with wildcards' {
        $plan = Get-StepPlan @{ Step = 'Intune.*', 'defender.spf'; IncludePreview = $true }
        @($plan | Where-Object Disposition -EQ 'Run' | ForEach-Object { $_.Test.Id } | Sort-Object) | Should -Be @('PRQ.2', 'PRQ.3')
        ($plan | Where-Object { $_.Test.Id -eq 'PRQ.1' }).ReasonCode | Should -Be 'NotSelected'
    }

    It '-IncludePrerequisites adds the tests of the prerequisites, preview tests too, and nothing else' {
        $plan = Get-StepPlan @{ TestId = 'PRQ.1'; IncludePrerequisites = $true }
        @($plan | Where-Object Disposition -EQ 'Run' | ForEach-Object { $_.Test.Id } | Sort-Object) | Should -Be @('PRQ.1', 'PRQ.2')
        ($plan | Where-Object { $_.Test.Id -eq 'PRQ.2' }).Prerequisite | Should -BeTrue
        ($plan | Where-Object { $_.Test.Id -eq 'PRQ.3' }).Disposition | Should -Be 'NotRun'
    }

    It 'Keeps the exclusions when it adds prerequisites' {
        $plan = Get-StepPlan @{ TestId = 'PRQ.1'; ExcludeTestId = 'PRQ.2'; IncludePrerequisites = $true }
        ($plan | Where-Object { $_.Test.Id -eq 'PRQ.2' }).ReasonCode | Should -Be 'ExcludedById'
    }

    It 'Leaves out a Pester-format test, which names no step' {
        $miss = InModuleScope Maester {
            $selection = Resolve-MtSelection -RunConfig (Resolve-MtRunConfig -Config @{}) -Step 'entra.*'
            Test-MtSelectorMatch -Selection $selection -Suite 'Custom'
        }
        $miss.Selector | Should -Be 'Step'
    }

    It 'Get-MtTest -Step filters the same way' {
        @(Get-MtTest -Path $script:prqFolder -Step 'intune.*').Id | Should -Be @('PRQ.2')
    }

    It 'Puts the step of a family instance on its row' {
        $values = InModuleScope Maester { Get-MtInstanceAttribute -Instance @{ Id = 'a'; Step = @('Entra.Base', 'not a step') } -Product 'entra' }
        $values.Step | Should -Be @('entra.base')
    }
}

Describe 'Outputs of the defender''s path' {
    BeforeAll {
        $path = Get-Path -Row $script:rows -Measure $script:halfCompliant
        $script:result = [pscustomobject]@{
            TenantId = 't1'; TenantName = 'Contoso'; CurrentVersion = '3.1.0'; ExecutedAt = '2026-11-06'; TotalCount = 3; PassedCount = 1; FailedCount = 2
            InvestigateCount = 0; SkippedCount = 0; NotRunCount = 0; ErrorCount = 0; Tests = @($script:rows); Steps = $path.Steps; Goals = $path.Goals
        }
    }

    It 'Adds Step, Readiness and BlockedBy columns to the CSV rows' {
        $flat = @(Convert-MtResultsToFlatObject -InputObject $script:result -PassThru)
        $goal = $flat | Where-Object ID -EQ 'T.goal'
        $goal.Step | Should -Be 'entra.goal'
        $goal.Readiness | Should -Be 'Blocked'
        $goal.BlockedBy | Should -Be 'intune.policies, intune.compliant'
        ($flat | Where-Object ID -EQ 'T.base').Readiness | Should -Be ''
    }

    It 'Starts the Markdown report with the Ready steps and a count of the others' {
        $markdown = InModuleScope Maester -Parameters @{ R = $script:result } { Get-MtMarkdownReport -MaesterResults $R }
        $markdown.Contains('## Do these first') | Should -BeTrue
        $markdown.Contains('1. **Policies** (`intune.policies`)') | Should -BeTrue
        $markdown.Contains('T.pol: Title of T.pol') | Should -BeTrue
        $markdown.Contains('2 steps are blocked, and 0 steps have prerequisites to check first.') | Should -BeTrue
        $markdown.Contains('%DefendersPath%') | Should -BeFalse
        $markdown.IndexOf('## Do these first') | Should -BeLessThan $markdown.IndexOf('## Test summary')
    }

    It 'Leaves the Markdown report as it was without Steps' {
        $plain = $script:result | Select-Object -Property * -ExcludeProperty Steps, Goals
        $markdown = InModuleScope Maester -Parameters @{ R = $plain } { Get-MtMarkdownReport -MaesterResults $R }
        $markdown.Contains('Do these first') | Should -BeFalse
        $markdown.Contains('%DefendersPath%') | Should -BeFalse
    }

    It 'Adds one line to the console summary' {
        $console = [pscustomobject]@{ Mode = 'Stream'; CI = $null; Ansi = $false; Unicode = $false; ColorDepth = 'None'; Width = 120; Taskbar = $false; Hyperlink = $false }
        $lines = @(InModuleScope Maester -Parameters @{ c = $console; r = $script:result } { param($c, $r) Write-MtRunSummary -MaesterResults $r -Console $c 6>&1 } | ForEach-Object { "$_" })
        @($lines | Where-Object { $_ -like "*Defender's path:*" }) | Should -Be @(" Defender's path: 1 ready, 2 blocked, 0 to check first")
        $plain = $script:result | Select-Object -Property * -ExcludeProperty Steps, Goals
        $without = @(InModuleScope Maester -Parameters @{ c = $console; r = $plain } { param($c, $r) Write-MtRunSummary -MaesterResults $r -Console $c 6>&1 } | ForEach-Object { "$_" })
        @($without | Where-Object { $_ -like "*Defender's path*" }).Count | Should -Be 0
    }
}

Describe 'ConvertTo-MtMaesterResult with steps' {
    BeforeEach {
        InModuleScope Maester {
            $__MtSession.TestResultDetail = @{}
            $__MtSession.MaesterConfig = [PSCustomObject]@{ GlobalSettings = [PSCustomObject]@{}; TestSettings = @(); TestSettingsHash = @{} }
        }
        Mock Test-MtConnection -ModuleName Maester { $false }
        Mock Get-MtModuleVersion -ModuleName Maester { '0.0.0-test' }
        Mock Get-MtLatestModuleVersion -ModuleName Maester { $null }
    }
    AfterEach {
        InModuleScope Maester { $__MtSession.MaesterConfig = $null }
    }

    It 'Writes Steps and Goals and schema 2.2 when a row names a step, and Step on the row' {
        $result = InModuleScope Maester {
            $row = [pscustomobject]@{
                Index = 0; Id = 'CONTOSO.1'; Title = 'Emergency access is excluded'; Name = 'CONTOSO.1: Emergency access is excluded'; HelpUrl = ''; Severity = 'High'
                Tag = @(); Result = 'Failed'; Block = 'Entra ID'; Product = 'entra'; ResultDetail = $null; ReasonCode = $null; ParentId = $null
                Step = [string[]]@('entra.emergency-access-excluded')
            }
            ConvertTo-MtMaesterResult -NativeRows @($row) -SkipVersionCheck
        }
        $result.SchemaVersion | Should -Be '2.2'
        # Both are Ready; the step recommended first comes first.
        @($result.Steps.Id) | Should -Be @('entra.emergency-access-accounts', 'entra.emergency-access-excluded')
        $result.Steps[0].Status | Should -Be 'NotChecked'
        $step = $result.Steps[1]
        $step.Status | Should -Be 'NotDone'
        $step.Readiness | Should -Be 'Ready'
        ($step.Tests | Where-Object Id -EQ 'MT.1005').ReasonCode | Should -Be 'NotInRun'
        $result.Goals.Id | Should -Contain 'compliant-devices'
    }

    It 'Writes no Steps when no row names a step' {
        $result = InModuleScope Maester {
            $row = [pscustomobject]@{ Index = 0; Id = 'CONTOSO.2'; Title = 't'; Name = 'CONTOSO.2: t'; HelpUrl = ''; Severity = 'High'; Tag = @(); Result = 'Passed'; Block = 'Custom'; Product = $null; ResultDetail = $null; ReasonCode = $null; ParentId = $null; Step = [string[]]@() }
            ConvertTo-MtMaesterResult -NativeRows @($row) -SkipVersionCheck
        }
        $result.PSObject.Properties['Steps'] | Should -BeNullOrEmpty
        $result.PSObject.Properties['Goals'] | Should -BeNullOrEmpty
    }
}
