BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force

    $script:createdAdStubs = @()
    foreach ($cmd in 'Get-ADDomain', 'Get-ADRootDSE', 'Get-GPO') {
        if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
            New-Item -Path "function:global:$cmd" -Value { } | Out-Null
            $script:createdAdStubs += $cmd
        }
    }
}

AfterAll {
    foreach ($cmd in $script:createdAdStubs) {
        Remove-Item -Path "function:global:$cmd" -ErrorAction SilentlyContinue
    }
}

Describe 'Active Directory collectors require an explicit connection' {
    BeforeEach {
        InModuleScope Maester {
            $__MtSession.ADConnection = $null
            $__MtSession.ADCache = @{
                DomainState = [PSCustomObject]@{ Domain = 'cached-domain-state' }
                Dacls       = @('cached-dacl')
                GpoState    = [PSCustomObject]@{ GPOs = @('cached-gpo-state') }
            }
        }

        Mock Get-ADDomain -ModuleName Maester { throw 'Get-ADDomain must not be called without an explicit connection.' }
        Mock Get-ADRootDSE -ModuleName Maester { throw 'Get-ADRootDSE must not be called without an explicit connection.' }
        Mock Get-GPO -ModuleName Maester { throw 'Get-GPO must not be called without an explicit connection.' }
    }

    AfterEach {
        InModuleScope Maester {
            $__MtSession.ADConnection = $null
            $__MtSession.ADCache = @{}
        }
    }

    It 'Does not collect or return cached domain state' {
        Get-MtADDomainState | Should -BeNullOrEmpty
        Should -Invoke Get-ADDomain -ModuleName Maester -Times 0 -Exactly
    }

    It 'Does not collect or return cached ACLs' {
        Get-MtADDacls | Should -BeNullOrEmpty
        Should -Invoke Get-ADDomain -ModuleName Maester -Times 0 -Exactly
    }

    It 'Does not collect or return cached Group Policy state' {
        Get-MtADGpoState | Should -BeNullOrEmpty
        Should -Invoke Get-ADRootDSE -ModuleName Maester -Times 0 -Exactly
        Should -Invoke Get-GPO -ModuleName Maester -Times 0 -Exactly
    }
}

Describe 'Active Directory Pester tests remain opt-in' {
    BeforeEach {
        $script:adTestPath = Join-Path $TestDrive ([guid]::NewGuid().ToString())
        $script:adResultPath = Join-Path $TestDrive "$([guid]::NewGuid()).json"
        $script:adMarkerPath = Join-Path $TestDrive "$([guid]::NewGuid()).marker"
        New-Item -Path $script:adTestPath -ItemType Directory | Out-Null

        $probeTest = @'
Describe 'AD opt-in probe' -Tag 'AD' {
    It 'AD-OPT-IN: runs only after an explicit connection' {
        New-Item -Path '__MARKER_PATH__' -ItemType File | Out-Null
        $true | Should -BeTrue
    }
}
'@
        $probeTest.Replace('__MARKER_PATH__', $script:adMarkerPath) |
            Set-Content -Path (Join-Path $script:adTestPath 'ActiveDirectory.Tests.ps1')

        InModuleScope Maester {
            $__MtSession.ADConnection = $null
        }
    }

    AfterEach {
        InModuleScope Maester {
            $__MtSession.ADConnection = $null
        }
    }

    It 'Does not run an AD-tagged test by default, even when -Tag AD is supplied' {
        Invoke-Maester -Path $script:adTestPath -Tag 'AD' -OutputJsonFile $script:adResultPath -SkipGraphConnect -NonInteractive -NoLogo -DisableTelemetry -SkipVersionCheck

        Test-Path $script:adMarkerPath | Should -BeFalse
    }

    It 'Runs an AD-tagged test after Active Directory was explicitly validated' {
        InModuleScope Maester {
            $__MtSession.ADConnection = [PSCustomObject]@{
                Connected        = $true
                DomainController = 'dc01.contoso.com'
            }
        }

        Invoke-Maester -Path $script:adTestPath -Tag 'AD' -OutputJsonFile $script:adResultPath -SkipGraphConnect -NonInteractive -NoLogo -DisableTelemetry -SkipVersionCheck

        Test-Path $script:adMarkerPath | Should -BeTrue
    }
}

Describe 'Active Directory test source safety' {
    It 'Keeps every AD test in a tagged Describe block with no discovery-time setup' {
        $repositoryRoot = Resolve-Path (Join-Path $PSScriptRoot '../../..')
        $adTestFiles = Get-ChildItem (Join-Path $repositoryRoot 'tests/ad') -Recurse -Filter '*.Tests.ps1'
        $issues = @()

        foreach ($file in $adTestFiles) {
            $tokens = $null
            $parseErrors = $null
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$parseErrors)

            foreach ($parseError in @($parseErrors)) {
                $issues += "$($file.FullName): parse error: $($parseError.Message)"
            }

            foreach ($statement in $ast.EndBlock.Statements) {
                $command = $statement.Find({
                        param($node)
                        $node -is [System.Management.Automation.Language.CommandAst]
                    }, $false) | Select-Object -First 1

                if ($null -eq $command -or $command.GetCommandName() -ne 'Describe') {
                    $issues += "$($file.FullName): contains setup outside a tagged Describe block."
                }
            }

            $describeCommands = $ast.FindAll({
                    param($node)
                    $node -is [System.Management.Automation.Language.CommandAst] -and $node.GetCommandName() -eq 'Describe'
                }, $true)

            foreach ($describe in $describeCommands) {
                if ($describe.Extent.Text -notmatch '(?s)-Tag\s+[''"]AD[''"]') {
                    $issues += "$($file.FullName): Describe block is missing the AD tag."
                }

                $block = $describe.CommandElements |
                    Where-Object { $_ -is [System.Management.Automation.Language.ScriptBlockExpressionAst] } |
                    Select-Object -Last 1

                foreach ($statement in $block.ScriptBlock.EndBlock.Statements) {
                    $command = $statement.Find({
                            param($node)
                            $node -is [System.Management.Automation.Language.CommandAst]
                        }, $false) | Select-Object -First 1

                    if ($null -eq $command -or $command.GetCommandName() -ne 'It') {
                        $issues += "$($file.FullName): Describe contains code that can execute during Pester discovery."
                    }
                }
            }
        }

        $adTestFiles.Count | Should -BeGreaterThan 0
        $issues | Should -BeNullOrEmpty
    }

    It 'Routes every public AD test command through a guarded collector before any AD operation' {
        $repositoryRoot = Resolve-Path (Join-Path $PSScriptRoot '../../..')
        $adCommandFiles = Get-ChildItem (Join-Path $repositoryRoot 'powershell/public/ad') -Recurse -Filter 'Test-MtAd*.ps1'
        $issues = @()

        foreach ($file in $adCommandFiles) {
            $tokens = $null
            $parseErrors = $null
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$parseErrors)

            foreach ($parseError in @($parseErrors)) {
                $issues += "$($file.FullName): parse error: $($parseError.Message)"
            }

            $commands = $ast.FindAll({
                    param($node)
                    $node -is [System.Management.Automation.Language.CommandAst]
                }, $true)
            $collector = $commands |
                Where-Object { $_.GetCommandName() -in 'Get-MtADDomainState', 'Get-MtADDacls', 'Get-MtADGpoState' } |
                Sort-Object { $_.Extent.StartOffset } |
                Select-Object -First 1

            if ($null -eq $collector) {
                $issues += "$($file.FullName): does not call a guarded Active Directory collector."
                continue
            }

            $earlierAdOperation = $commands |
                Where-Object {
                    $_.Extent.StartOffset -lt $collector.Extent.StartOffset -and
                    ($_.GetCommandName() -match '^(Get-AD|Get-GPO|Get-DnsServer)' -or $_.GetCommandName() -eq 'Invoke-Command')
                } |
                Select-Object -First 1

            if ($null -ne $earlierAdOperation) {
                $issues += "$($file.FullName): calls $($earlierAdOperation.GetCommandName()) before checking the explicit AD connection."
            }
        }

        $adCommandFiles.Count | Should -BeGreaterThan 0
        $issues | Should -BeNullOrEmpty
    }
}
