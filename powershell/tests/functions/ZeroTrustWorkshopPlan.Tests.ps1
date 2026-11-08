Describe 'Zero Trust Workshop plan' {
    BeforeAll {
        Import-Module $PSScriptRoot/../../Maester.psd1 -Force -WarningAction SilentlyContinue
        $script:PackRoot = (Resolve-Path "$PSScriptRoot/../../../packs/zero-trust-assessment").Path
        $script:Workshop = Join-Path $script:PackRoot 'workshop'
        $script:RepoRoot = (Resolve-Path "$PSScriptRoot/../../..").Path
        foreach ($helper in 'Get-MtZtaWorkshopValue', 'Read-MtZtaWorkshopFile', 'ConvertTo-MtZtaWorkshopTask', 'Get-MtZtaWorkshopPlan', 'Add-MtZtaWorkshopPlan') {
            . (Join-Path $script:PackRoot "helpers/$helper.ps1")
        }

        function Write-FixtureJson([string] $Path, $Object) {
            $null = New-Item -ItemType Directory -Path (Split-Path $Path -Parent) -Force
            Set-Content -LiteralPath $Path -Value ($Object | ConvertTo-Json -Depth 10) -Encoding utf8NoBOM
        }
    }

    Context 'Get-MtZtaWorkshopPlan' {
        BeforeAll {
            $script:Fixture = Join-Path $TestDrive 'workshop'
            Write-FixtureJson (Join-Path $script:Fixture 'identity.json') ([ordered]@{
                    Id = 'identity'; Name = 'Identity'
                    Source = [ordered]@{ Url = 'https://zerotrust.microsoft.com'; Updated = '2026-11-01' }
                    Areas = @([ordered]@{ Id = 'access'; Name = 'Access'; Description = 'Access controls'; Icon = 'access.svg' })
                    Tasks = @(
                        [ordered]@{ Id = 'RMI_001'; Name = 'Design Conditional Access'; AreaId = 'access'; Swimlane = 'Access'; Phase = 'First'; Priority = 'P0'
                            Effort = 'Medium'; UserImpact = 'Low'; License = 'Entra-P1'; Cisa = 'Initial'; Dependencies = @(); Icon = 'RMI_001.svg'
                            Link = 'https://example.test/RMI_001'; Doc = '## Overview'; Checks = @('ZTA.100', 'ZTA.200') }
                        [ordered]@{ Id = 'RMI_002'; Name = 'Roll out risk policies'; AreaId = 'access'; Phase = 'Then'; Dependencies = @('RMI_001'); Checks = @() }
                    )
                })
            Write-FixtureJson (Join-Path $script:Fixture 'devices.json') ([ordered]@{
                    Id = 'devices'; Name = 'Devices'
                    Source = [ordered]@{ Url = 'https://zerotrust.microsoft.com'; Updated = '2026-11-03' }
                    Areas = @([ordered]@{ Id = 'mdm'; Name = 'MDM' })
                    Tasks = @([ordered]@{ Id = 'DEV-001'; Name = 'Enrol devices'; AreaId = 'mdm'; Dependencies = @(); Checks = @() })
                })
            Write-FixtureJson (Join-Path $script:Fixture 'icons.json') ([ordered]@{
                    Icons = [ordered]@{ 'access.svg' = '<svg>a</svg>'; 'RMI_001.svg' = '<svg>1</svg>'; 'unused.svg' = '<svg>u</svg>' }
                })
            Write-FixtureJson (Join-Path $script:Fixture 'maester.json') ([ordered]@{
                    Tasks = [ordered]@{
                        RMI_001 = [ordered]@{ Tests = @('MT.1003', 'MT.1057', 'ZTA.100'); Note = 'Maester also checks the gaps.' }
                    }
                    ExtraTasks = @([ordered]@{
                            Pillar = 'identity'; Id = 'MAE_SYNC'; Name = 'Harden sync'; AreaId = 'access'; Phase = 'Then'
                            Dependencies = @('RMI_001'); Tests = @('MT.1020', 'MT.1020'); Doc = 'Sync guidance'
                        })
                })
            $script:Taxonomy = Join-Path $TestDrive 'taxonomy.json'
            Write-FixtureJson $script:Taxonomy ([ordered]@{
                    Tests = [ordered]@{
                        '100' = [ordered]@{ AlsoCheckedBy = @('MT.1057', 'CIS.M365.5.2.2.16') }
                        '200' = [ordered]@{ AlsoCheckedBy = @('MT.1057') }
                    }
                })
            $script:Plan = Get-MtZtaWorkshopPlan -WorkshopPath $script:Fixture -TaxonomyPath $script:Taxonomy
            $script:Identity = $script:Plan.Pillars | Where-Object Id -EQ 'identity'
        }

        It 'returns the schema, the source and the pillars in the workshop order' {
            $script:Plan.Schema | Should -Be 'maester.zero-trust-workshop/1'
            $script:Plan.Source.Name | Should -Be 'Microsoft Zero Trust Workshop'
            $script:Plan.Source.Url | Should -Be 'https://zerotrust.microsoft.com'
            $script:Plan.Source.Updated | Should -Be '2026-11-03'
            $script:Plan.Pillars.Id | Should -Be @('identity', 'devices')
            $script:Identity.Name | Should -Be 'Identity'
            $script:Identity.Areas[0].Id | Should -Be 'access'
        }

        It 'lists Microsoft''s checks, then the same checks, then Maester''s, each once' {
            $task = $script:Identity.Tasks | Where-Object Id -EQ 'RMI_001'
            $task.Checks.Id | Should -Be @('ZTA.100', 'ZTA.200', 'MT.1057', 'CIS.M365.5.2.2.16', 'MT.1003')
            $task.Checks.Source | Should -Be @('microsoft', 'microsoft', 'same-check', 'same-check', 'maester')
            ($task.Checks | Where-Object Id -EQ 'MT.1057').Via | Should -Be 'ZTA.100'
            ($task.Checks | Where-Object Id -EQ 'MT.1003').PSObject.Properties.Name | Should -Not -Contain 'Via'
            $task.Note | Should -Be 'Maester also checks the gaps.'
            $task.Origin | Should -Be 'workshop'
        }

        It 'keeps the task fields and leaves out empty ones' {
            $task = $script:Identity.Tasks | Where-Object Id -EQ 'RMI_001'
            $task.Effort | Should -Be 'Medium'
            $task.Cisa | Should -Be 'Initial'
            $task.Doc | Should -Be '## Overview'
            $task.PSObject.Properties.Name | Should -Not -Contain 'Link'

            $other = $script:Identity.Tasks | Where-Object Id -EQ 'RMI_002'
            $other.PSObject.Properties.Name | Should -Not -Contain 'Note'
            $other.PSObject.Properties.Name | Should -Not -Contain 'Swimlane'
            @($other.Dependencies) | Should -Be @('RMI_001')
            @($other.Checks).Count | Should -Be 0
            $other.PSObject.Properties.Name | Should -Contain 'Checks'
        }

        It 'appends Maester''s extra tasks to their pillar' {
            $last = $script:Identity.Tasks[-1]
            $last.Id | Should -Be 'MAE_SYNC'
            $last.Origin | Should -Be 'maester'
            @($last.Checks).Count | Should -Be 1
            $last.Checks[0].Id | Should -Be 'MT.1020'
            $last.Checks[0].Source | Should -Be 'maester'
            $last.Doc | Should -Be 'Sync guidance'
        }

        It 'carries only the icons the plan uses' {
            $script:Plan.Icons.PSObject.Properties.Name | Sort-Object | Should -Be @('access.svg', 'RMI_001.svg')
            $script:Plan.Icons.'RMI_001.svg' | Should -Be '<svg>1</svg>'
        }

        It 'serializes the plan with arrays for single checks and dependencies' {
            $json = $script:Plan | ConvertTo-Json -Depth 10 -Compress
            $json | Should -BeLike '*"Dependencies":`["RMI_001"`]*'
            $json | Should -BeLike '*"Checks":`[{"Id":"MT.1020","Source":"maester"}`]*'
            $json | Should -BeLike '*"Checks":`[`]*'
        }

        It 'works without the overlay and the taxonomy, and returns nothing for an empty folder' {
            $bare = Join-Path $TestDrive 'bare'
            $null = New-Item -ItemType Directory -Path $bare -Force
            Copy-Item -LiteralPath (Join-Path $script:Fixture 'identity.json') -Destination $bare
            $plan = Get-MtZtaWorkshopPlan -WorkshopPath $bare
            ($plan.Pillars[0].Tasks | Where-Object Id -EQ 'RMI_001').Checks.Id | Should -Be @('ZTA.100', 'ZTA.200')
            @($plan.Pillars[0].Tasks).Count | Should -Be 2
            @($plan.Icons.PSObject.Properties).Count | Should -Be 0

            $empty = Join-Path $TestDrive 'empty'
            $null = New-Item -ItemType Directory -Path $empty -Force
            Get-MtZtaWorkshopPlan -WorkshopPath $empty | Should -BeNullOrEmpty
        }
    }

    Context 'Add-MtZtaWorkshopPlan' {
        It 'attaches the plan as JSON named zero-trust-workshop' {
            Mock Get-MtSetting { $true }
            Mock Add-MtReportAttachment {}

            Add-MtZtaWorkshopPlan -WorkshopPath $script:Workshop -TaxonomyPath (Join-Path $script:PackRoot 'taxonomy.json')

            Should -Invoke Add-MtReportAttachment -Times 1 -Exactly -ParameterFilter {
                $Name -eq 'zero-trust-workshop' -and $ContentType -eq 'application/json' -and ($Content | ConvertFrom-Json).Schema -eq 'maester.zero-trust-workshop/1'
            }
        }

        It 'reads the pack''s workshop folder by default' {
            Mock Get-MtSetting { $true }
            Mock Add-MtReportAttachment {}

            Add-MtZtaWorkshopPlan

            Should -Invoke Add-MtReportAttachment -Times 1 -Exactly -ParameterFilter { @(($Content | ConvertFrom-Json).Pillars).Count -eq 7 }
        }

        It 'adds nothing when the WorkshopPlan setting is false' {
            Mock Get-MtSetting { $false } -ParameterFilter { $Name -eq 'ZeroTrustAssessment.WorkshopPlan' }
            Mock Add-MtReportAttachment {}

            Add-MtZtaWorkshopPlan -WorkshopPath $script:Workshop

            Should -Invoke Add-MtReportAttachment -Times 0 -Exactly
        }

        It 'warns and never throws when the plan cannot be built' {
            Mock Get-MtSetting { $true }
            Mock Add-MtReportAttachment {}
            Mock Get-MtZtaWorkshopPlan { throw 'broken file' }

            { Add-MtZtaWorkshopPlan -WorkshopPath $script:Workshop -WarningVariable warnings -WarningAction SilentlyContinue } | Should -Not -Throw
            Add-MtZtaWorkshopPlan -WorkshopPath $script:Workshop -WarningVariable warnings -WarningAction SilentlyContinue
            $warnings | Should -BeLike '*broken file*'
            Should -Invoke Add-MtReportAttachment -Times 0 -Exactly
        }
    }

    Context 'the workshop files in the pack' {
        BeforeAll {
            $script:PillarIds = @('identity', 'devices', 'data', 'network', 'infrastructure', 'security-operations', 'ai')
            $script:Pillars = @{}
            foreach ($id in $script:PillarIds) {
                $path = Join-Path $script:Workshop "$id.json"
                if (Test-Path -LiteralPath $path) { $script:Pillars[$id] = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json -Depth 20 }
            }
            $script:Overlay = Get-Content -LiteralPath (Join-Path $script:Workshop 'maester.json') -Raw | ConvertFrom-Json -Depth 20
            $script:AllTaskIds = [System.Collections.Generic.HashSet[string]]::new()
            foreach ($pillar in $script:Pillars.Values) { foreach ($task in $pillar.Tasks) { $null = $script:AllTaskIds.Add($task.Id) } }
            foreach ($task in @($script:Overlay.ExtraTasks)) { $null = $script:AllTaskIds.Add($task.Id) }

            # Every built-in test ID, from the file names of the native tests.
            $script:TestIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
            foreach ($file in Get-ChildItem -Path (Join-Path $script:RepoRoot 'tests') -Recurse -File -Filter 'Test.*.ps1') {
                $null = $script:TestIds.Add(($file.BaseName -replace '^Test\.', ''))
            }
        }

        It 'has a generated file for each of the seven pillars' {
            foreach ($id in $script:PillarIds) {
                $script:Pillars.ContainsKey($id) | Should -BeTrue -Because "workshop/$id.json is written by the generator"
                $script:Pillars[$id].'$comment' | Should -BeLike 'Generated by build/zero-trust-workshop/Update-MtZtWorkshopData.ps1*'
                $script:Pillars[$id].Id | Should -Be $id
            }
        }

        It 'places every workshop task in an area of its pillar' {
            $problems = foreach ($pillar in $script:Pillars.Values) {
                $areas = @($pillar.Areas.Id)
                foreach ($task in $pillar.Tasks) { if ($task.AreaId -cnotin $areas) { "$($pillar.Id)/$($task.Id): $($task.AreaId)" } }
            }
            $problems | Should -BeNullOrEmpty
        }

        It 'names only built-in tests in maester.json' {
            $named = @($script:Overlay.Tasks.PSObject.Properties.Value.Tests) + @($script:Overlay.ExtraTasks.Tests) | Where-Object { $_ }
            $missing = @($named | Where-Object { -not $script:TestIds.Contains($_) })
            $missing | Should -BeNullOrEmpty
        }

        It 'adds Maester tests only to tasks the workshop has' {
            $workshopIds = [System.Collections.Generic.HashSet[string]]::new()
            foreach ($pillar in $script:Pillars.Values) { foreach ($task in $pillar.Tasks) { $null = $workshopIds.Add($task.Id) } }
            $unknown = @($script:Overlay.Tasks.PSObject.Properties.Name | Where-Object { -not $workshopIds.Contains($_) })
            $unknown | Should -BeNullOrEmpty
        }

        It 'places extra tasks in a pillar and area that exist, after tasks that exist' {
            $workshopIds = [System.Collections.Generic.HashSet[string]]::new()
            foreach ($pillar in $script:Pillars.Values) { foreach ($task in $pillar.Tasks) { $null = $workshopIds.Add($task.Id) } }
            foreach ($task in @($script:Overlay.ExtraTasks)) {
                $script:Pillars.ContainsKey($task.Pillar) | Should -BeTrue -Because "$($task.Id) names pillar $($task.Pillar)"
                $task.AreaId | Should -BeIn @($script:Pillars[$task.Pillar].Areas.Id) -Because "$($task.Id) names area $($task.AreaId)"
                $workshopIds.Contains($task.Id) | Should -BeFalse -Because "$($task.Id) must not reuse a workshop task ID"
                foreach ($dependency in @($task.Dependencies)) {
                    $script:AllTaskIds.Contains($dependency) | Should -BeTrue -Because "$($task.Id) depends on $dependency"
                }
            }
        }

        It 'maps workshop tasks to assessment tests of the catalog, or warns' {
            # Microsoft's mapping follows the assessment's main branch, so it can name a test that the module version
            # the pack is built for does not have yet, or has dropped. The plan shows such a check as not run, so a
            # gap is a warning, not a failure; a malformed ID fails.
            $catalog = Get-Content -LiteralPath (Join-Path $script:PackRoot 'catalog.json') -Raw | ConvertFrom-Json
            $known = [System.Collections.Generic.HashSet[string]]::new([string[]]@($catalog.Tests.Id))
            $checks = @($script:Pillars.Values | ForEach-Object { $_.Tasks } | ForEach-Object { $_.Checks } | Where-Object { $_ } | Sort-Object -Unique)
            $checks | Where-Object { $_ -notmatch '^ZTA\.\d+$' } | Should -BeNullOrEmpty
            $unknown = @($checks | Where-Object { -not $known.Contains($_) })
            if ($unknown.Count -gt 0) {
                Write-Warning "The Zero Trust Workshop maps tasks to assessment tests that catalog.json does not have: $($unknown -join ', ')."
            }
        }

        It 'builds a plan of the seven pillars from the pack' {
            $plan = Get-MtZtaWorkshopPlan -WorkshopPath $script:Workshop -TaxonomyPath (Join-Path $script:PackRoot 'taxonomy.json')
            $plan.Pillars.Id | Should -Be $script:PillarIds
            ($plan.Pillars | Where-Object Id -EQ 'identity').Tasks.Origin | Should -Contain 'maester'
            foreach ($pillar in $plan.Pillars) {
                foreach ($task in $pillar.Tasks) {
                    @($task.Checks.Id | Group-Object | Where-Object Count -GT 1) | Should -BeNullOrEmpty -Because "$($task.Id) lists each check once"
                }
            }
        }
    }
}
