# The result fields a report needs beyond the rows: the framework catalogues (Frameworks), the packs of the run
# (Packs), the previous run (Previous), and on rows the facts of a family instance (Fields) and the test a
# benchmark shim returns (ShimOf). See website/docs/result-schema.md.

BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force -WarningAction SilentlyContinue
    $script:repoRoot = (Resolve-Path "$PSScriptRoot/../../..").Path
}

Describe 'Get-MtResultFramework' {
    It 'Returns nothing when no row names a framework' {
        InModuleScope Maester {
            @(Get-MtResultFramework -InputObject @([pscustomobject]@{ Benchmark = $null; Control = @() })) | Should -BeNullOrEmpty
        }
    }

    It 'Lists the whole catalogue of a framework a row names, with its facts and without Related' {
        InModuleScope Maester {
            $row = [pscustomobject]@{ Benchmark = [pscustomobject]@{ Framework = 'cis-m365'; Requirement = '1.1.1' }; Control = @('cis-m365:1.1.1') }
            $cis = @(Get-MtResultFramework -InputObject @($row)) | Where-Object Key -EQ 'cis-m365'
            $cis.Complete | Should -BeTrue
            $cis.Name | Should -Not -BeNullOrEmpty
            $cis.Version | Should -Not -BeNullOrEmpty
            @($cis.Requirements).Count | Should -BeGreaterThan 100
            $first = $cis.Requirements | Where-Object Id -EQ '1.1.1'
            $first.Level | Should -Be 'L1'
            $first.PSObject.Properties.Name | Should -Not -Contain 'Related'
        }
    }

    It 'Lists only the named requirements of a large catalogue, and says it is not complete' {
        InModuleScope Maester {
            $row = [pscustomobject]@{ Benchmark = $null; Control = @('ism:ISM-1403') }
            $ism = @(Get-MtResultFramework -InputObject @($row)) | Where-Object Key -EQ 'ism'
            $ism.Complete | Should -BeFalse
            @($ism.Requirements.Id) | Should -Be @('ISM-1403')
        }
    }

    It 'Lists the named NIST SP 800-53 controls with their title and family' {
        InModuleScope Maester {
            $row = [pscustomobject]@{ Benchmark = $null; Control = @('nist-800-53-r5:AC-2', 'nist-800-53-r5:IA-2(1)') }
            $nist = @(Get-MtResultFramework -InputObject @($row)) | Where-Object Key -EQ 'nist-800-53-r5'
            $nist.Complete | Should -BeFalse
            @($nist.Requirements.Id) | Should -Be @('AC-2', 'IA-2(1)')
            ($nist.Requirements | Where-Object Id -EQ 'AC-2').Family | Should -Be 'Access Control'
        }
    }

    It 'Gives no entry for a framework Maester does not ship' {
        InModuleScope Maester {
            @(Get-MtResultFramework -InputObject @([pscustomobject]@{ Benchmark = $null; Control = @('contoso-baseline:1.1') })) | Should -BeNullOrEmpty
        }
    }
}

Describe 'Get-MtResultPack' {
    It 'Describes each pack that is not turned off, from its manifest and lock entry' {
        InModuleScope Maester {
            $set = @(
                [pscustomobject]@{ Id = 'maester.zero-trust-assessment'; Version = '0.1.0'; BuiltIn = $true; Status = 'Ready'; ReasonCode = $null; Reason = $null; Entry = $null
                    Manifest = [pscustomobject]@{ Code = 'ZTA'; Name = 'Microsoft Zero Trust Assessment'; Description = 'Runs the assessment.'; Publisher = 'maester365'; Homepage = 'https://maester.dev/docs/packs/zero-trust-assessment' } }
                [pscustomobject]@{ Id = 'contoso.baseline'; Version = $null; BuiltIn = $false; Status = 'Unavailable'; ReasonCode = 'PackUnavailable'; Reason = 'The repository is gone.'; Manifest = $null
                    Entry = [pscustomobject]@{ Version = '1.2.0'; Publisher = 'contoso'; AcceptedRisk = 'Medium' } }
                [pscustomobject]@{ Id = 'contoso.off'; Version = '1.0.0'; BuiltIn = $false; Status = 'Disabled'; ReasonCode = 'DisabledByConfig'; Reason = 'Off.'; Manifest = $null; Entry = $null }
            )
            $packs = @(Get-MtResultPack -PackSet $set)
            @($packs.Id) | Should -Be @('maester.zero-trust-assessment', 'contoso.baseline')

            $packs[0].Code | Should -Be 'ZTA'
            $packs[0].Name | Should -Be 'Microsoft Zero Trust Assessment'
            $packs[0].BuiltIn | Should -BeTrue
            $packs[0].Risk | Should -BeNullOrEmpty
            $packs[0].Status | Should -Be 'Ready'

            $packs[1].Name | Should -Be 'contoso.baseline'
            $packs[1].Version | Should -Be '1.2.0'
            $packs[1].Publisher | Should -Be 'contoso'
            $packs[1].Risk | Should -Be 'Medium'
            $packs[1].ReasonCode | Should -Be 'PackUnavailable'
        }
    }
}

Describe 'Get-MtPreviousResult' {
    BeforeAll {
        $script:folder = Join-Path $TestDrive 'results'
        $null = New-Item -ItemType Directory -Path $script:folder
        $write = {
            param($name, $tenant, $executedAt, $tests, $minutesAgo)
            $path = Join-Path $script:folder $name
            [pscustomobject]@{ TenantId = $tenant; ExecutedAt = $executedAt; Tests = $tests } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $path
            (Get-Item -LiteralPath $path).LastWriteTimeUtc = [datetime]::UtcNow.AddMinutes(-$minutesAgo)
            $path
        }
        $null = & $write 'TestResults-2026-10-19-090000.json' 'tenant-a' '2026-10-19T09:00:00+11:00' @(@{ Id = 'MT.1001'; Result = 'Failed' }) 30
        $null = & $write 'TestResults-2026-10-26-090000.json' 'tenant-a' '2026-10-26T09:00:00+11:00' @(@{ Id = 'MT.1001'; Result = 'Passed' }, @{ Name = 'MT.1002: Legacy row'; Result = 'Failed' }) 20
        $null = & $write 'TestResults-2026-10-27-090000.json' 'tenant-b' '2026-10-27T09:00:00+11:00' @(@{ Id = 'MT.1001'; Result = 'Failed' }) 10
        $script:current = & $write 'TestResults-2026-11-02-090000.json' 'tenant-a' '2026-11-02T09:00:00+11:00' @(@{ Id = 'MT.1001'; Result = 'Failed' }) 0
    }

    It 'Returns the newest earlier result for the tenant, skipping this run''s file and other tenants' {
        InModuleScope Maester -Parameters @{ Folder = $script:folder; Current = $script:current } {
            $previous = Get-MtPreviousResult -Folder $Folder -TenantId 'tenant-a' -Exclude $Current
            $previous.File | Should -Be 'TestResults-2026-10-26-090000.json'
            $previous.Results.'MT.1001' | Should -Be 'Passed'
            [datetimeoffset]::Parse($previous.ExecutedAt).UtcDateTime | Should -Be ([datetimeoffset]::Parse('2026-10-26T09:00:00+11:00').UtcDateTime)
        }
    }

    It 'Takes the ID of a 2.x row from its Name' {
        InModuleScope Maester -Parameters @{ Folder = $script:folder; Current = $script:current } {
            (Get-MtPreviousResult -Folder $Folder -TenantId 'tenant-a' -Exclude $Current).Results.'MT.1002' | Should -Be 'Failed'
        }
    }

    It 'Lists the counts of earlier runs for the tenant, newest first, from the start of each file' {
        InModuleScope Maester -Parameters @{ Root = $TestDrive } {
            $folder = Join-Path $Root 'history'
            $null = New-Item -ItemType Directory -Path $folder
            foreach ($day in 20, 27, 29) {
                [ordered]@{ FailedCount = $day; PassedCount = 100 - $day; TotalCount = 100; ExecutedAt = "2026-10-$($day)T09:00:00+11:00"; TenantId = 'tenant-a'; Tests = @(@{ Id = 'MT.1001'; Result = 'Failed' }) } |
                    ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $folder "TestResults-2026-10-$day.json")
            }
            [ordered]@{ FailedCount = 1; TotalCount = 1; ExecutedAt = '2026-10-30T09:00:00+11:00'; TenantId = 'tenant-b'; Tests = @() } |
                ConvertTo-Json | Set-Content -LiteralPath (Join-Path $folder 'TestResults-other.json')

            $previous = Get-MtPreviousResult -Folder $folder -TenantId 'tenant-a'
            $previous.File | Should -Be 'TestResults-2026-10-29.json'
            $previous.History.Count | Should -Be 3
            $previous.History[0].Failed | Should -Be 29
            $previous.History[2].Failed | Should -Be 20
            $previous.History[0].Total | Should -Be 100
            (Get-MtPreviousResult -Folder $folder -TenantId 'tenant-a' -HistoryCount 2).History.Count | Should -Be 2
        }
    }

    It 'Returns nothing for a missing folder or a tenant with no earlier result' {
        InModuleScope Maester -Parameters @{ Folder = $script:folder; Current = $script:current } {
            Get-MtPreviousResult -Folder (Join-Path $Folder 'missing') -TenantId 'tenant-a' | Should -BeNullOrEmpty
            Get-MtPreviousResult -Folder $Folder -TenantId 'tenant-c' -Exclude $Current | Should -BeNullOrEmpty
        }
    }
}

Describe 'ConvertTo-MtMaesterResult report data' {
    BeforeEach {
        InModuleScope Maester {
            $__MtSession.TestResultDetail = @{}
            $__MtSession.MaesterConfig = [PSCustomObject]@{ GlobalSettings = [PSCustomObject]@{}; TestSettings = @(); TestSettingsHash = @{} }
        }
        Mock Test-MtConnection -ModuleName Maester { $false }
    }

    It 'Adds Frameworks always, and Packs only when the run had packs' {
        InModuleScope Maester {
            $row = [pscustomobject]@{ Id = 'CIS.M365.1.1.1'; Title = 'x'; Name = 'CIS.M365.1.1.1: x'; Result = 'Passed'; Severity = 'High'; Tag = @(); Block = 'Microsoft 365'; Product = 'microsoft-365'
                Benchmark = [pscustomobject]@{ Framework = 'cis-m365'; Requirement = '1.1.1' }; Control = @('cis-m365:1.1.1'); ResultDetail = $null; Index = 0; Duration = '00:00:00.000'; Format = 'Native' }
            $without = ConvertTo-MtMaesterResult -NativeRows @($row) -SkipVersionCheck
            @($without.Frameworks.Key) | Should -Contain 'cis-m365'
            $without.PSObject.Properties.Name | Should -Not -Contain 'Packs'
            $without.PSObject.Properties.Name | Should -Not -Contain 'Previous'

            $context = [pscustomobject]@{ PackSet = @([pscustomobject]@{ Id = 'contoso.baseline'; Version = '1.0.0'; BuiltIn = $false; Status = 'Ready'; ReasonCode = $null; Reason = $null; Manifest = [pscustomobject]@{ Code = 'CNT'; Name = 'Contoso' }; Entry = $null }) }
            $with = ConvertTo-MtMaesterResult -NativeRows @($row) -SkipVersionCheck -RunContext $context
            @($with.Packs.Code) | Should -Be @('CNT')
        }
    }
}

Describe 'Family instance Fields' {
    It 'Writes the simple values of an instance''s Fields to its row and leaves out the rest' {
        InModuleScope Maester {
            $fields = ConvertTo-MtInstanceField @{ Pillar = @('Identity', '', $null); Category = 'Access control'; Raw = [pscustomobject]@{ Secret = 'x' }; Empty = ''; Count = 3 }
            $fields.Pillar | Should -Be @('Identity')
            $fields.Category | Should -Be 'Access control'
            $fields.Count | Should -Be '3'
            $fields.PSObject.Properties.Name | Should -Not -Contain 'Raw'
            $fields.PSObject.Properties.Name | Should -Not -Contain 'Empty'
            ConvertTo-MtInstanceField $null | Should -BeNullOrEmpty
            ConvertTo-MtInstanceField @{ Raw = @{ a = 1 } } | Should -BeNullOrEmpty
        }
    }

    It 'Carries Fields from the instance source to the row' {
        $folder = Join-Path $TestDrive 'fields'
        $null = New-Item -ItemType Directory -Path $folder
        Set-Content -LiteralPath (Join-Path $folder 'Test.CONTOSO.FIELDS.ps1') -Value @'
function Get-ContosoFieldInstance {
    [CmdletBinding()]
    param()
    [pscustomobject]@{ Id = 'a'; Fields = @{ Pillar = @('Identity'); Category = 'Access control' } }
    [pscustomobject]@{ Id = 'b' }
}

function Test-ContosoFields {
    [MaesterTest(Id = 'CONTOSO.FIELDS', Title = 'Fields fixture', InstanceSource = 'Get-ContosoFieldInstance')]
    [CmdletBinding()]
    [OutputType([bool])]
    param($Instance)
    return $true
}
'@
        Set-Content -LiteralPath (Join-Path $folder 'Test.CONTOSO.FIELDS.md') -Value 'A family whose instances carry Fields.'
        Push-Location $TestDrive
        try { $rows = @(Invoke-MtTest -Path $folder 3>$null 6>$null) } finally { Pop-Location }
        $a = $rows | Where-Object Id -EQ 'CONTOSO.FIELDS.a'
        $b = $rows | Where-Object Id -EQ 'CONTOSO.FIELDS.b'
        $a.Fields.Pillar | Should -Be @('Identity')
        $a.Fields.Category | Should -Be 'Access control'
        $b.Fields | Should -BeNullOrEmpty
    }
}

Describe 'ShimOf' {
    It 'Finds the command of a body that is one return of one Test-Mt* command, and nothing else' {
        InModuleScope Maester {
            $function = {
                param($text)
                [System.Management.Automation.Language.Parser]::ParseInput($text, [ref]$null, [ref]$null).Find({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)
            }
            Get-MtShimCommand -Function (& $function 'function Test-A { return Test-MtCisMfaForEveryUser }') | Should -Be 'Test-MtCisMfaForEveryUser'
            Get-MtShimCommand -Function (& $function 'function Test-A { return Test-MtCisMfaForEveryUser -Threshold 5 }') | Should -Be 'Test-MtCisMfaForEveryUser'
            Get-MtShimCommand -Function (& $function 'function Test-A { $x = 1; return Test-MtCisMfaForEveryUser }') | Should -BeNullOrEmpty
            Get-MtShimCommand -Function (& $function 'function Test-A { return Get-MgUser }') | Should -BeNullOrEmpty
            Get-MtShimCommand -Function (& $function 'function Test-A { return Test-MtA | Select-Object -First 1 }') | Should -BeNullOrEmpty
        }
    }

    It 'Names the test a built-in shim returns' {
        InModuleScope Maester {
            $tests = @(Get-MtNativeTestInventory -Path (Get-MtMaesterTestFolderPath) -Root (Get-MtMaesterTestFolderPath) -BuiltIn -WarningAction SilentlyContinue)
            ($tests | Where-Object Id -EQ 'ASD.ISM-1504').ShimOf | Should -Be 'CIS.M365.5.2.2.2'
            ($tests | Where-Object Id -EQ 'CIS.M365.5.2.2.2').ShimOf | Should -BeNullOrEmpty
        }
    }
}
