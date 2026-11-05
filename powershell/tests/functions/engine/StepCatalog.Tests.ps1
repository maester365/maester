# The step catalogue of the defender's path (docs/proposals/defenders-path.md, sections 4, 5 and 14): how
# Get-MtStepCatalog reads a catalogue folder and what it reports as a problem, how Get-MtStepProblem checks the steps
# that tests and packs name, and how the reader treats the Step attribute.
#
# Each catalogue is written to TestDrive from a valid base: three entra steps and one intune step under one goal.
BeforeAll {
    Import-Module "$PSScriptRoot/../../../Maester.psd1" -Force -WarningAction SilentlyContinue

    function New-Source {
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Test helper that returns a hashtable.')]
        param([string] $Url = 'https://learn.microsoft.com/entra/identity/example')
        [ordered]@{ Url = $Url; Note = 'Do the other step first.'; Reviewed = '2026-11-05' }
    }

    # The files of a valid catalogue, as hashtables to change before they are written.
    function Get-BaseCatalog {
        @{
            'goals.json'  = [ordered]@{ Goals = @([ordered]@{ Id = 'goal'; Title = 'A goal'; Summary = 'What the goal achieves.'; Step = 'entra.c' }) }
            'entra.json'  = [ordered]@{
                Product = 'entra'
                Steps   = @(
                    [ordered]@{ Id = 'entra.a'; Title = 'Step A'; Summary = 'A.'; Sources = @(New-Source) }
                    [ordered]@{ Id = 'entra.b'; Title = 'Step B'; Summary = 'B.'; Requires = @('entra.a'); OnlyWhen = @('hybrid-identity'); Sources = @(New-Source) }
                    [ordered]@{
                        Id = 'entra.c'; Title = 'Step C'; Summary = 'C.'; Requires = @('entra.b'); RequiresOneOf = @(, @('entra.a', 'intune.d'))
                        Rollout = @('Report-only first.', 'Then everyone.'); Sources = @((New-Source), [ordered]@{ Maintainer = 'merill'; Note = 'From experience.'; Reviewed = '2026-11-05' })
                    }
                )
            }
            'intune.json' = [ordered]@{ Product = 'intune'; Steps = @([ordered]@{ Id = 'intune.d'; Title = 'Step D'; Summary = 'D.'; Unchecked = 'No check yet.'; Sources = @(New-Source 'https://learn.microsoft.com/intune/example') }) }
        }
    }

    # Writes a catalogue to a new TestDrive folder and reads it.
    function Read-Catalog {
        param([hashtable] $Files)
        $folder = Join-Path $TestDrive ('steps' + [guid]::NewGuid().ToString('n'))
        $null = New-Item -ItemType Directory -Path $folder
        foreach ($name in $Files.Keys) {
            $value = $Files[$name]
            $text = if ($value -is [string]) { $value } else { ConvertTo-Json -InputObject $value -Depth 10 }
            Set-Content -LiteralPath (Join-Path $folder $name) -Value $text
        }
        InModuleScope Maester -Parameters @{ F = $folder } { Get-MtStepCatalog -Path $F }
    }

    # The problems of a catalogue after a change to the base.
    function Get-Problem {
        param([scriptblock] $Change)
        $files = Get-BaseCatalog
        & $Change $files
        @((Read-Catalog $files).Problems)
    }

    # Writes a measure registry to TestDrive and reads it.
    function Read-Registry {
        param([string] $Text)
        $file = Join-Path $TestDrive ('measures' + [guid]::NewGuid().ToString('n') + '.psd1')
        Set-Content -LiteralPath $file -Value $Text
        InModuleScope Maester -Parameters @{ F = $file } { Get-MtMeasureRegistry -Path $F }
    }
    # A registry with one valid measure, whose reader is a function the module has.
    $script:validRegistryText = "@{ Measures = @( @{ Key = 'devices-compliant'; Function = 'Get-MtStepCatalog'; Title = 'Devices that sign in are compliant'; Unit = 'devices'; Service = 'Graph'; License = 'INTUNE_A'; Permission = 'Graph:Scope:Device.Read.All' } ) }"

    # The step of the base catalogue with the given ID, to change.
    function Get-Step {
        param([hashtable] $Files, [string] $Id)
        $file = "$($Id.Split('.')[0]).json"
        $Files[$file].Steps | Where-Object { $_.Id -eq $Id }
    }
}

Describe 'Get-MtStepCatalog' {
    Context 'A valid catalogue' {
        BeforeAll { $script:valid = Read-Catalog (Get-BaseCatalog) }

        It 'Has no problems' {
            $script:valid.Problems | Should -BeNullOrEmpty
        }

        It 'Reads every step with all its fields, lists as arrays' {
            $script:valid.Steps.Keys | Should -Be @('entra.a', 'entra.b', 'entra.c', 'intune.d')
            $c = $script:valid.Steps['entra.c']
            $c.Product | Should -Be 'entra'
            $c.File | Should -Be 'entra.json'
            $c.Requires | Should -Be @('entra.b')
            $c.RequiresOneOf[0] | Should -Be @('entra.a', 'intune.d')
            $c.RecommendedFirst | Should -HaveCount 0
            $c.Rollout | Should -Be @('Report-only first.', 'Then everyone.')
            $c.Sources | Should -HaveCount 2
            $c.Sources[1].Maintainer | Should -Be 'merill'
            $script:valid.Steps['entra.b'].OnlyWhen | Should -Be @('hybrid-identity')
            $script:valid.Steps['intune.d'].Unchecked | Should -Be 'No check yet.'
        }

        It 'Gives a goal its step and every prerequisite, prerequisites first' {
            $script:valid.Goals | Should -HaveCount 1
            $script:valid.Goals[0].Steps | Should -Be @('entra.a', 'entra.b', 'intune.d', 'entra.c')
        }

        It 'Keeps a Reviewed date as yyyy-MM-dd text' {
            $script:valid.Steps['entra.a'].Sources[0].Reviewed | Should -Be '2026-11-05'
        }
    }

    Context 'Problems' {
        It 'Reports a relationship to a step that is not in the catalogue' {
            Get-Problem { param($f) (Get-Step $f 'entra.c').Requires = @('entra.b', 'entra.missing') } |
                Should -Contain "entra.json (entra.c): Requires names 'entra.missing', which is not in the catalogue."
        }

        It 'Reports a step that names itself' {
            Get-Problem { param($f) (Get-Step $f 'entra.a').RecommendedFirst = @('entra.a') } |
                Should -Contain 'entra.json (entra.a): RecommendedFirst names the step itself.'
        }

        It 'Reports a step named in two relationships' {
            Get-Problem { param($f) (Get-Step $f 'entra.c').RecommendedFirst = @('entra.b') } |
                Should -Contain "entra.json (entra.c): 'entra.b' is in both Requires and RecommendedFirst."
        }

        It 'Reports a RequiresOneOf group of one step' {
            Get-Problem { param($f) (Get-Step $f 'entra.c').RequiresOneOf = @(, @('entra.a')) } |
                Should -Contain 'entra.json (entra.c): each RequiresOneOf group lists at least two steps.'
        }

        It 'Reports a cycle once, with its path' {
            $problems = Get-Problem { param($f) (Get-Step $f 'entra.a').Requires = @('entra.b') }
            @($problems | Where-Object { $_ -like '*in a cycle*' }) | Should -HaveCount 1
            $problems | Should -Contain 'entra.json (entra.a): the steps depend on each other in a cycle: entra.a -> entra.b -> entra.a.'
        }

        It 'Reports a condition that is not known' {
            Get-Problem { param($f) (Get-Step $f 'entra.b').OnlyWhen = @('on-premises') } |
                Should -Contain "entra.json (entra.b): OnlyWhen has 'on-premises', which is not a known condition (hybrid-identity, license:<service plan>)."
        }

        It 'Accepts a licence condition' {
            Get-Problem { param($f) (Get-Step $f 'entra.b').OnlyWhen = @('license:AAD_PREMIUM_P2') } | Should -BeNullOrEmpty
        }

        It 'Reports a source with a locale, one that is not on Learn, and one without Reviewed' {
            # Split, so that the repository's check for language-specific URLs does not flag this file.
            $localeUrl = 'https://learn.microsoft.com/' + 'en-us/entra/x'
            $problems = Get-Problem {
                param($f)
                (Get-Step $f 'entra.a').Sources = @(
                    (New-Source $localeUrl),
                    (New-Source 'https://example.com/x'),
                    [ordered]@{ Url = 'https://learn.microsoft.com/entra/y'; Note = 'N.' }
                )
            }
            $problems | Should -Contain "entra.json (entra.a): the source '$localeUrl' has a locale. Leave it out, as the check guides do."
            $problems | Should -Contain "entra.json (entra.a): the source 'https://example.com/x' is not a Microsoft Learn URL."
            $problems | Should -Contain 'entra.json (entra.a): a source needs Reviewed, the date it was last read against the step (yyyy-MM-dd).'
        }

        It 'Reports a step with no source and a Note that is too long' {
            $problems = Get-Problem {
                param($f)
                (Get-Step $f 'entra.a').Sources = @()
                (Get-Step $f 'entra.b').Sources = @([ordered]@{ Url = 'https://learn.microsoft.com/entra/x'; Note = ('x' * 201); Reviewed = '2026-11-05' })
            }
            $problems | Should -Contain 'entra.json (entra.a): a step needs at least one source.'
            $problems | Should -Contain "entra.json (entra.b): A source's Note is longer than 200 characters."
        }

        It 'Reports a step file whose Product is not its name, and a step outside its product' {
            $problems = Get-Problem {
                param($f)
                $f['intune.json'].Product = 'entra'
                (Get-Step $f 'entra.a').Id = 'intune.a'
                (Get-Step $f 'entra.b').Requires = @('intune.a')
            }
            $problems | Should -Contain "intune.json: Product is 'entra'. A step file is named after its product, so it must be 'intune'."
            $problems | Should -Contain "entra.json: the step 'intune.a' must start with 'entra.', the product of its file."
        }

        It 'Reports a file named after a product the taxonomy does not have' {
            $problems = Get-Problem { param($f) $f['contoso.json'] = [ordered]@{ Product = 'contoso'; Steps = @() } }
            $problems | Should -Contain "contoso.json: 'contoso' is not a product key of the taxonomy registry."
        }

        It 'Reports a step that is in two files, an unknown key and an invalid ID' {
            $problems = Get-Problem {
                param($f)
                $f['entra.json'].Steps += [ordered]@{ Id = 'entra.a'; Title = 'Again'; Summary = 'Again.'; Sources = @(New-Source) }
                (Get-Step $f 'entra.b').Severity = 'High'
                $f['entra.json'].Steps += [ordered]@{ Id = 'Entra.Upper'; Title = 'Upper'; Summary = 'U.'; Sources = @(New-Source) }
            }
            $problems | Should -Contain "entra.json: the step 'entra.a' is also in entra.json."
            $problems | Should -Contain "entra.json (entra.b): unknown key 'Severity'."
            $problems | Should -Contain "entra.json: 'Entra.Upper' is not a step ID (<product-key>.<name>, lowercase)."
        }

        It 'Reports a step in no goal, and a goal whose step is missing' {
            $problems = Get-Problem {
                param($f)
                $f['intune.json'].Steps += [ordered]@{ Id = 'intune.orphan'; Title = 'Orphan'; Summary = 'O.'; Sources = @(New-Source) }
                $f['goals.json'].Goals += [ordered]@{ Id = 'other'; Title = 'Other'; Summary = 'O.'; Step = 'entra.missing' }
            }
            $problems | Should -Contain 'intune.json (intune.orphan): the step belongs to no goal. Make it a goal''s step or a prerequisite of one.'
            $problems | Should -Contain "goals.json (other): Step names 'entra.missing', which is not in the catalogue."
        }

        It 'Reads a Measure, and reports one that is wrong or sits beside Unchecked' {
            $files = Get-BaseCatalog
            $d = Get-Step $files 'intune.d'
            $d.Remove('Unchecked')
            $d.Measure = [ordered]@{ Key = 'devices-compliant'; MinimumShare = 90 }
            $catalog = Read-Catalog $files
            $catalog.Problems | Should -BeNullOrEmpty
            $catalog.Steps['intune.d'].Measure.Key | Should -Be 'devices-compliant'
            $catalog.Steps['intune.d'].Measure.MinimumShare | Should -Be 90
            $catalog.Steps['entra.a'].Measure | Should -BeNullOrEmpty

            $problems = Get-Problem {
                param($f)
                (Get-Step $f 'intune.d').Measure = [ordered]@{ Key = 'Devices'; MinimumShare = 0; Extra = 1 }
                (Get-Step $f 'entra.a').Measure = 'devices-compliant'
            }
            $problems | Should -Contain "intune.json (intune.d): Measure has the unknown key 'Extra'."
            $problems | Should -Contain "intune.json (intune.d): Measure's Key 'Devices' is not a measure key (lowercase kebab-case)."
            $problems | Should -Contain "intune.json (intune.d): Measure's MinimumShare must be a whole number from 1 to 100."
            $problems | Should -Contain 'intune.json (intune.d): the step has a Measure, so it must not have Unchecked.'
            $problems | Should -Contain 'entra.json (entra.a): Measure must be an object with Key and MinimumShare.'
        }

        It 'Reports a missing goals file and a file that is not JSON' {
            $files = Get-BaseCatalog
            $files.Remove('goals.json')
            $files['intune.json'] = '{ not json'
            $problems = @((Read-Catalog $files).Problems)
            $problems | Should -Contain 'goals.json: the catalogue has no goals file.'
            @($problems | Where-Object { $_ -like 'intune.json: the file is not valid JSON*' }) | Should -HaveCount 1
        }
    }
}

Describe 'Get-MtStepProblem' {
    BeforeAll {
        $script:catalog = Read-Catalog (Get-BaseCatalog)
        function New-FakeTest {
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Test helper that returns an object.')]
            param([string] $Id, [string[]] $Step)
            [pscustomobject]@{ Id = $Id; File = "/tests/Test.$Id.ps1"; Step = $Step }
        }
        $script:registry = Read-Registry $script:validRegistryText
        function Get-TestProblem {
            param([object[]] $Test, [string] $PackRoot, [object] $Catalog = $script:catalog, [object] $Registry = $script:registry)
            InModuleScope Maester -Parameters @{ T = $Test; C = $Catalog; P = $PackRoot; R = $Registry } { @(Get-MtStepProblem -Test $T -Catalog $C -Registry $R -PackRoot $P -Coverage) }
        }
        # The base catalogue with a Measure in place of Unchecked on intune.d.
        function Get-MeasureCatalog {
            param([string] $Key = 'devices-compliant')
            $files = Get-BaseCatalog
            $d = Get-Step $files 'intune.d'
            $d.Remove('Unchecked')
            $d.Measure = [ordered]@{ Key = $Key; MinimumShare = 95 }
            Read-Catalog $files
        }
    }

    It 'Has no problems when every checked step has a test and the rest say why not' {
        Get-TestProblem @((New-FakeTest 'T.1' @('entra.a')), (New-FakeTest 'T.2' @('entra.b', 'entra.c'))) | Should -BeNullOrEmpty
    }

    It 'Reports a test that names a step the catalogue does not have' {
        Get-TestProblem @((New-FakeTest 'T.1' @('entra.a', 'entra.nope')), (New-FakeTest 'T.2' @('entra.b', 'entra.c'))) |
            Should -Contain "/tests/Test.T.1.ps1: the test T.1 names the step 'entra.nope', which is not in the step catalogue."
    }

    It 'Reports a step no test names that has no Unchecked, and a named step that has one' {
        $problems = Get-TestProblem @((New-FakeTest 'T.1' @('entra.a', 'intune.d')))
        $problems | Should -Contain 'entra.json (entra.b): no test names the step and it has no Measure. Name it in the Step attribute of the tests that verify it, give it a Measure, or say why neither can in Unchecked.'
        $problems | Should -Contain 'intune.json (intune.d): T.1 verify the step, so it must not have Unchecked.'
    }

    It 'Leaves out the Unchecked check without -Coverage, as the build does for a folder that holds only some tests' {
        $problems = InModuleScope Maester -Parameters @{ C = $script:catalog; R = $script:registry } { @(Get-MtStepProblem -Test @() -Catalog $C -Registry $R) }
        $problems | Should -BeNullOrEmpty
    }

    It 'Counts a step with a Measure as checked' {
        Get-TestProblem @((New-FakeTest 'T.1' @('entra.a')), (New-FakeTest 'T.2' @('entra.b', 'entra.c'))) -Catalog (Get-MeasureCatalog) |
            Should -BeNullOrEmpty
    }

    It 'Reports a Measure key the registry does not have' {
        Get-TestProblem @((New-FakeTest 'T.1' @('entra.a')), (New-FakeTest 'T.2' @('entra.b', 'entra.c'))) -Catalog (Get-MeasureCatalog 'mfa-registered') |
            Should -Contain "intune.json (intune.d): Measure names 'mfa-registered', which is not in the measure registry."
    }

    It 'Reports a registry entry whose reader does not exist, and entries that are wrong' {
        $registry = Read-Registry @"
@{ Measures = @(
    @{ Key = 'devices-compliant'; Function = 'Get-MtNoSuchReader'; Title = 'Devices'; Unit = 'devices'; Service = 'Graph' }
    @{ Key = 'Bad Key'; Function = 'Get-MtStepCatalog'; Title = 'T'; Unit = 'u'; Service = 'Graph' }
    @{ Key = 'mfa-registered'; Function = 'reader'; Unit = 'users'; Service = 'NoSuchService'; Permission = 'not a permission'; Colour = 'red' }
) }
"@
        $problems = Get-TestProblem @((New-FakeTest 'T.1' @('entra.a')), (New-FakeTest 'T.2' @('entra.b', 'entra.c'))) -Catalog (Get-MeasureCatalog) -Registry $registry
        $name = [System.IO.Path]::GetFileName($registry.Path)
        $problems | Should -Contain "$name (devices-compliant): the reader function Get-MtNoSuchReader does not exist."
        $problems | Should -Contain "${name}: 'Bad Key' is not a measure key (lowercase kebab-case)."
        $problems | Should -Contain "$name (mfa-registered): Function must name a Maester function, Verb-MtNoun."
        $problems | Should -Contain "$name (mfa-registered): Title must be one line of text."
        $problems | Should -Contain "$name (mfa-registered): Service 'NoSuchService' is not in the service registry."
        $problems | Should -Contain "$name (mfa-registered): Permission 'not a permission' is not valid. Write <Service>:<Kind>:<Name>."
        $problems | Should -Contain "$name (mfa-registered): unknown key 'Colour'."
    }

    It 'Counts the steps a pack names in its taxonomy.json' {
        $packs = Join-Path $TestDrive 'packs'
        $null = New-Item -ItemType Directory -Path (Join-Path $packs 'zta') -Force
        '{ "Tests": { "100": { "Product": "entra", "Step": ["entra.b"] }, "101": { "Step": ["entra.unknown"] } } }' |
            Set-Content (Join-Path $packs 'zta/taxonomy.json')
        $problems = Get-TestProblem @((New-FakeTest 'T.1' @('entra.a')), (New-FakeTest 'T.2' @('entra.c'))) -PackRoot $packs
        @($problems | Where-Object { $_ -like '*entra.b*' }) | Should -BeNullOrEmpty
        @($problems | Where-Object { $_ -like "*the test 101 names the step 'entra.unknown'*" }) | Should -HaveCount 1
    }
}

Describe 'The Step attribute' {
    BeforeAll {
        function Read-StepTest {
            param([string] $Step)
            $folder = Join-Path $TestDrive ('t' + [guid]::NewGuid().ToString('n'))
            $null = New-Item -ItemType Directory -Path $folder
            "function Test-StepFixture {`n    [MaesterTest(Id = 'STEP.1', Title = 'Step fixture', Step = $Step, Service = 'None')]`n    [CmdletBinding()]`n    param()`n    `$true`n}" |
                Set-Content (Join-Path $folder 'Test.STEP.1.ps1')
            'Description.' | Set-Content (Join-Path $folder 'Test.STEP.1.md')
            InModuleScope Maester -Parameters @{ F = (Join-Path $folder 'Test.STEP.1.ps1') } { Read-MtNativeTest -Path $F }
        }
    }

    It 'Reads one step or a list, and drops repeats' {
        (Read-StepTest "'entra.a'").Step | Should -Be @('entra.a')
        $t = Read-StepTest "('entra.a', 'intune.d', 'entra.a')"
        $t.Step | Should -Be @('entra.a', 'intune.d')
        $t.Errors | Should -BeNullOrEmpty
    }

    It 'Stores a step in lowercase' {
        (Read-StepTest "'Entra.CA-Require'").Step | Should -Be @('entra.ca-require')
    }

    It 'Rejects a value that is not a step ID' {
        @((Read-StepTest "'entra_a'").Errors.Message) | Should -Contain "Property 'Step' value 'entra_a' is not valid."
    }

    It 'Rejects more than three steps' {
        @((Read-StepTest "('entra.a', 'entra.b', 'entra.c', 'intune.d')").Errors.Message) |
            Should -Contain "Property 'Step' names 4 steps. A test verifies at most three; a test that checks more is several tests."
    }

    It 'Defaults to an empty list' {
        $folder = Join-Path $TestDrive 'nostep'
        $null = New-Item -ItemType Directory -Path $folder
        "function Test-NoStep {`n    [MaesterTest(Id = 'STEP.2', Title = 'No step', Service = 'None')]`n    [CmdletBinding()]`n    param()`n    `$true`n}" | Set-Content (Join-Path $folder 'Test.STEP.2.ps1')
        'Description.' | Set-Content (Join-Path $folder 'Test.STEP.2.md')
        $t = InModuleScope Maester -Parameters @{ F = (Join-Path $folder 'Test.STEP.2.ps1') } { Read-MtNativeTest -Path $F }
        $t.Step.Count | Should -Be 0
    }
}
