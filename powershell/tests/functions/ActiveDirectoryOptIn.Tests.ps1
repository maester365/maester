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

    It 'Does not collect domain state from a legacy-only connection marker' {
        InModuleScope Maester {
            $__MtSession.ADConnection = [PSCustomObject]@{
                Connected         = $true
                ProtocolValidated = $false
            }
        }

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

        # AD checks migrated to the native format are opt-in through their declared service instead of a
        # Describe tag: the engine runs them only after Connect-Maester -Service ActiveDirectory.
        $nativeAdFiles = @(Get-ChildItem (Join-Path $repositoryRoot 'tests/ad') -Recurse -Filter 'Test.*.ps1')
        foreach ($file in $nativeAdFiles) {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$null, [ref]$null)
            $attribute = $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.AttributeAst] -and $node.TypeName.Name -eq 'MaesterTest' }, $true) | Select-Object -First 1
            $service = $attribute.NamedArguments | Where-Object ArgumentName -EQ 'Service'
            if (-not $service -or $service.Argument.Extent.Text -notmatch 'ActiveDirectory') {
                $issues += "$($file.FullName): a native AD test must declare Service = 'ActiveDirectory'."
            }
        }

        ($adTestFiles.Count + $nativeAdFiles.Count) | Should -BeGreaterThan 0
        $issues | Should -BeNullOrEmpty
    }

    It 'Routes every public AD test command through a guarded collector before any AD operation' {
        $repositoryRoot = Resolve-Path (Join-Path $PSScriptRoot '../../..')
        # Public AD check commands, and AD checks migrated to native tests (tests/ad/**/Test.*.ps1).
        $adCommandFiles = @(Get-ChildItem (Join-Path $repositoryRoot 'powershell/public/ad') -Recurse -Filter 'Test-MtAd*.ps1' -ErrorAction SilentlyContinue) +
        @(Get-ChildItem (Join-Path $repositoryRoot 'tests/ad') -Recurse -Filter 'Test.*.ps1')
        $guardedCollectors = @('Get-MtADDomainState', 'Get-MtADDacls', 'Get-MtADGpoState')

        # Thin native AD tests call a shared helper in powershell/internal/checks/ad/ instead of a collector.
        # A helper counts as guarded when it calls a guarded collector itself; helpers are scanned like checks.
        $adHelperFiles = @(Get-ChildItem (Join-Path $repositoryRoot 'powershell/internal/checks/ad') -Recurse -Filter '*.ps1' -ErrorAction SilentlyContinue)
        $guardedHelpers = @()
        foreach ($helperFile in $adHelperFiles) {
            $helperAst = [System.Management.Automation.Language.Parser]::ParseFile($helperFile.FullName, [ref]$null, [ref]$null)
            $helperFunctions = $helperAst.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)
            foreach ($helperFunction in $helperFunctions) {
                $callsCollector = $helperFunction.Body.FindAll({
                        param($node)
                        $node -is [System.Management.Automation.Language.CommandAst] -and $node.GetCommandName() -in $guardedCollectors
                    }, $true) | Select-Object -First 1
                if ($null -ne $callsCollector) { $guardedHelpers += $helperFunction.Name }
            }
        }
        $adCommandFiles += $adHelperFiles
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
                Where-Object { $_.GetCommandName() -in ($guardedCollectors + $guardedHelpers) } |
                Sort-Object { $_.Extent.StartOffset } |
                Select-Object -First 1

            if ($null -eq $collector) {
                $issues += "$($file.FullName): does not call a guarded Active Directory collector."
            }

            $bannedOperation = $commands |
                Where-Object {
                    ($_.GetCommandName() -match '^(Get-AD|Get-GPO|Get-DnsServer)' -or $_.GetCommandName() -eq 'Invoke-Command')
                } |
                Select-Object -First 1

            if ($null -ne $bannedOperation) {
                $issues += "$($file.FullName): calls banned command $($bannedOperation.GetCommandName())."
            }

            $bannedType = $ast.FindAll({
                    param($node)
                    ($node -is [System.Management.Automation.Language.TypeExpressionAst] -or
                        $node -is [System.Management.Automation.Language.TypeConstraintAst]) -and
                    $node.TypeName.FullName -match '(^|\.)(ADSI|DirectoryEntry|DirectorySearcher)$'
                }, $true) | Select-Object -First 1

            if ($null -ne $bannedType) {
                $issues += "$($file.FullName): uses banned type $($bannedType.TypeName.FullName)."
            }

            $bannedTypeCommand = $commands |
                Where-Object {
                    $_.GetCommandName() -eq 'New-Object' -and
                    $_.Extent.Text -match '(?i)(^|\.)(DirectoryEntry|DirectorySearcher)\b'
                } |
                Select-Object -First 1

            if ($null -ne $bannedTypeCommand) {
                $issues += "$($file.FullName): constructs a banned DirectoryEntry or DirectorySearcher type."
            }
        }

        $adCommandFiles.Count | Should -BeGreaterThan 0
        $issues | Should -BeNullOrEmpty
    }

    It 'Requires explicit authorization before the standalone AD runner connects or invokes tests' {
        $repositoryRoot = Resolve-Path (Join-Path $PSScriptRoot '../../..')
        $runnerPath = Join-Path $repositoryRoot 'build/active-directory/Run-ADTests-And-CopyReports.ps1'
        $runnerContent = Get-Content -Path $runnerPath -Raw

        $authorizationGuardOffset = $runnerContent.IndexOf('if (-not $ConnectActiveDirectory.IsPresent)')
        $importOffset = $runnerContent.IndexOf('Import-Module $manifestPath')
        $connectOffset = $runnerContent.IndexOf('Connect-Maester -Service ActiveDirectory')
        $invokeOffset = $runnerContent.IndexOf('$results = Invoke-Maester')

        $authorizationGuardOffset | Should -BeGreaterOrEqual 0
        $importOffset | Should -BeGreaterThan $authorizationGuardOffset
        $connectOffset | Should -BeGreaterThan $importOffset
        $invokeOffset | Should -BeGreaterThan $connectOffset
    }

    It 'Includes the explicit AD connection in every documented AD invocation block' {
        $repositoryRoot = Resolve-Path (Join-Path $PSScriptRoot '../../..')
        $documentationPaths = @(
            (Join-Path $repositoryRoot 'build/active-directory/azure-lab/CONTRIBUTING-E2E.md')
            (Join-Path $repositoryRoot 'website/blog/2026-04-25-active-directory-security-testing/index.md')
        )
        $issues = @()

        foreach ($documentationPath in $documentationPaths) {
            $content = Get-Content -Path $documentationPath -Raw
            $codeBlocks = [regex]::Matches($content, '(?ms)```(?:powershell|yaml)\s*(.*?)```')

            foreach ($codeBlock in $codeBlocks) {
                $code = $codeBlock.Groups[1].Value

                if ($code -match '(?:Invoke-Maester|Test-MtAd[\w-]*)' -and
                    $code -notmatch 'Connect-Maester\s+-Service\s+ActiveDirectory') {
                    $issues += "$documentationPath contains an AD invocation block without an explicit Active Directory connection."
                }

                if ($code -match 'Run-ADTests-And-CopyReports\.ps1' -and
                    $code -notmatch '-ConnectActiveDirectory') {
                    $issues += "$documentationPath contains an AD runner example without explicit authorization."
                }
            }
        }

        $issues | Should -BeNullOrEmpty
    }
}
