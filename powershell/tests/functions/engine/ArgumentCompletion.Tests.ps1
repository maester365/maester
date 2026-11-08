BeforeAll {
    Import-Module "$PSScriptRoot/../../../Maester.psd1" -Force -WarningAction SilentlyContinue

    # What Tab offers at the end of a command line: the completion texts, as PowerShell would insert them.
    function Get-CompletionText {
        param([string] $Line)
        @((TabExpansion2 -inputScript $Line -cursorColumn $Line.Length).CompletionMatches | ForEach-Object CompletionText)
    }

    # A folder of custom tests, with values that need quotes.
    $script:customRoot = Join-Path $TestDrive 'custom-tests'
    $null = New-Item -Path $script:customRoot -ItemType Directory -Force
    Set-Content -LiteralPath (Join-Path $script:customRoot 'Test.CUSTOM.1.ps1') -Value @'
function Test-MtCustomCompletionOne {
    [MaesterTest(
        Id       = 'CUSTOM.1',
        Title    = 'A custom test with its own product',
        Severity = 'Low',
        Product  = 'My Product',
        Feature  = 'my-feature',
        Tag      = ('Team A', 'Nightly')
    )]
    [CmdletBinding()]
    param()
    $true
}
'@

    # A lock file with one installed pack.
    $script:lockFile = Join-Path $TestDrive 'maester-packs.lock.json'
    Set-Content -LiteralPath $script:lockFile -Value (@{
            LockVersion = 1
            Packs       = @(@{ Id = 'contoso.sample'; Version = '1.0.0'; Publisher = 'contoso'; Tests = @('MP.CTS.1', 'MP.CTS.2'); Services = @('CTS.Thing') })
            Modules     = @()
        } | ConvertTo-Json -Depth 5)
}

Describe 'Tab completion' {
    Context 'Registration' {
        It 'names an exported command and one of its parameters in every row' {
            $problems = foreach ($row in (InModuleScope Maester { Get-MtArgumentCompleterTable })) {
                $command = Get-Command -Module Maester -Name $row.Command -ErrorAction SilentlyContinue
                if (-not $command) { "$($row.Command) is not exported" }
                elseif (-not $command.Parameters.ContainsKey($row.Parameter)) { "$($row.Command) has no -$($row.Parameter)" }
            }
            $problems | Should -BeNullOrEmpty
        }

        It 'completes every selector parameter of an exported command' {
            $selectors = 'Product', 'ExcludeProduct', 'Feature', 'Area', 'Severity', 'Suite', 'Tag', 'ExcludeTag', 'TestId', 'ExcludeTestId', 'Pack'
            # A ValidateSet completes already; Get-MtTestInventory reads Pester-format tests, whose tags need Pester discovery.
            $exempt = @('Get-MtTestInventory/ExcludeTag')
            $table = @(InModuleScope Maester { Get-MtArgumentCompleterTable } | ForEach-Object { "$($_.Command)/$($_.Parameter)" })
            $missing = foreach ($command in Get-Command -Module Maester -CommandType Function) {
                foreach ($name in $selectors) {
                    if (-not $command.Parameters.ContainsKey($name)) { continue }
                    if ($command.Parameters[$name].Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }) { continue }
                    $key = "$($command.Name)/$name"
                    if ($key -notin $table -and $key -notin $exempt) { $key }
                }
            }
            $missing | Should -BeNullOrEmpty
        }

        It 'serves an alias of a command' {
            Get-CompletionText 'Invoke-MtMaester -Product exo' | Should -Contain 'exchange'
        }
    }

    Context 'Taxonomy selectors' {
        It 'completes a product key from its start' {
            @(Get-CompletionText 'Invoke-Maester -Product en')[0] | Should -Be 'entra'
        }

        It 'completes a product key from an alias' {
            Get-CompletionText 'Invoke-Maester -Product exo' | Should -Be @('exchange')
        }

        It 'gives the display name and aliases in the tooltip' {
            $match = (TabExpansion2 -inputScript 'Invoke-Maester -Product exo' -cursorColumn 27).CompletionMatches[0]
            $match.ToolTip | Should -Match 'Exchange Online'
            $match.ToolTip | Should -Match 'EXO'
        }

        It 'leaves out the values already in the list' {
            $offered = Get-CompletionText 'Invoke-Maester -Area authentication,a'
            $offered | Should -Not -Contain 'authentication'
            $offered | Should -Contain 'access-control'
        }

        It 'lists the features of the product on the line' {
            Get-CompletionText 'Invoke-Maester -Product exchange -Feature ' | Should -Not -Contain 'conditional-access'
            Get-CompletionText "Invoke-Maester -Product 'Entra ID' -Feature cond" | Should -Be @('conditional-access')
        }

        It 'lists the areas in the order of the taxonomy' {
            $areas = @(InModuleScope Maester { (Get-MtTaxonomy).Areas.Key })
            Get-CompletionText 'Invoke-Maester -Area ' | Should -Be $areas
        }

        It 'lists the severities from Critical to Info' {
            Get-CompletionText 'Invoke-Maester -Severity ' | Should -Be @('Critical', 'High', 'Medium', 'Low', 'Info')
        }

        It 'lists only the values that still select a test' {
            Get-CompletionText 'Invoke-Maester -Suite CISA -Severity ' | Should -Not -Contain 'Info'
        }

        It 'lists the suites of the built-in tests' {
            $suites = @(InModuleScope Maester { (Get-MtCompletionIndex).Tests.Suite } | Sort-Object -Unique)
            Get-CompletionText 'Invoke-Maester -Suite ' | Should -Be $suites
        }

        It 'lists every product for -ExcludeProduct, whatever the other selectors' {
            Get-CompletionText 'Invoke-Maester -Suite EIDSCA -ExcludeProduct ' | Should -Contain 'exchange'
        }

        It 'explains a Maester 2.x tag with the selector that replaces it' {
            $match = (TabExpansion2 -inputScript 'Invoke-Maester -Tag AD' -cursorColumn 22).CompletionMatches | Where-Object CompletionText -EQ 'AD'
            $match.ToolTip | Should -Match '-Product ad'
        }

        It 'completes the taxonomy keys for New-MtTest' {
            Get-CompletionText 'New-MtTest -Product exchange -Feature anti-' | Should -Contain 'anti-phishing'
            Get-CompletionText 'New-MtTest -ResourceType Cond' | Should -Be @('ConditionalAccessPolicy')
            Get-CompletionText 'New-MtTest -Mitre T1078' | Should -Contain 'T1078.004'
        }
    }

    Context 'Test IDs' {
        It 'lists the IDs that start with the word, in natural order' {
            $offered = Get-CompletionText 'Invoke-Maester -TestId MT.100'
            $offered | Should -Not -BeNullOrEmpty
            $offered | ForEach-Object { $_ | Should -BeLike 'MT.100*' }
            $offered | Should -Be @($offered | Sort-Object { [int]($_ -replace '\D', '') })
        }

        It 'offers the next ID segment as a wildcard first' {
            $offered = @(Get-CompletionText 'Invoke-Maester -TestId CISA.MS.')
            $offered[0] | Should -Be 'CISA.MS.AAD.*'
            $offered | Should -Contain 'CISA.MS.EXO.*'
        }

        It 'finds the tests that implement a requirement' {
            Get-CompletionText 'Invoke-Maester -TestId MS.AAD.3.1' | Should -Contain 'CISA.MS.AAD.3.1'
        }

        It 'searches the titles, keeping the quote the user typed' {
            Get-CompletionText "Invoke-Maester -TestId 'phishing resistant" | Should -Contain "'CISA.MS.AAD.3.1'"
        }

        It 'lists only the tests the other selectors leave' {
            $offered = Get-CompletionText 'Invoke-Maester -Suite CIS -TestId '
            $offered | Should -Not -BeNullOrEmpty
            $offered | ForEach-Object { $_ | Should -BeLike 'CIS.*' }
        }

        It 'leaves out the built-in tests with -SkipBuiltIn' {
            Get-CompletionText 'Invoke-Maester -SkipBuiltIn -TestId MT.10' | Should -Not -Contain 'MT.1005'
        }

        It 'offers the instances of a family as a wildcard' {
            Get-CompletionText 'Invoke-Maester -TestId MT.1024' | Should -Contain 'MT.1024.*'
        }

        It 'completes Get-MtTest and Invoke-MtTest -Id' {
            Get-CompletionText 'Get-MtTest -Id MT.100' | Should -Contain 'MT.1005'
            Get-CompletionText 'Invoke-MtTest -Id MT.100' | Should -Contain 'MT.1005'
        }
    }

    Context 'Custom tests under -Path' {
        It 'completes the IDs of the custom tests' {
            Get-CompletionText "Invoke-Maester -Path '$script:customRoot' -TestId CUS" | Should -Contain 'CUSTOM.1'
        }

        It 'lists only the tests under -Path for Get-MtTest' {
            Get-CompletionText "Get-MtTest -Path '$script:customRoot' -Id " | Should -Be @('CUSTOM.1')
        }

        It 'quotes a value with a space' {
            Get-CompletionText "Invoke-Maester -Path '$script:customRoot' -Product My" | Should -Be @("'My Product'")
            Get-CompletionText "Invoke-Maester -Path '$script:customRoot' -Tag Team" | Should -Contain "'Team A'"
        }

        It 'keeps the double quote the user typed' {
            Get-CompletionText "Invoke-Maester -Path '$script:customRoot' -Product `"My" | Should -Be @('"My Product"')
        }
    }

    Context 'Packs, services, settings and roles' {
        It 'completes the code of a built-in pack' {
            @(Get-CompletionText 'Invoke-Maester -Pack ZT')[0] | Should -Be 'ZTA'
        }

        It 'completes the tests of a pack named with -Pack' {
            Get-CompletionText 'Invoke-Maester -Pack ZTA -TestId ZTA.' | Should -Not -BeNullOrEmpty
        }

        It 'completes the packs of the lock file on the line' {
            Get-CompletionText "Invoke-Maester -PackLock '$script:lockFile' -Pack CT" | Should -Contain 'CTS'
            Get-CompletionText "Invoke-Maester -PackLock '$script:lockFile' -Pack CTS -TestId MP." | Should -Contain 'MP.CTS.1'
        }

        It 'offers only installed packs to uninstall' {
            $offered = Get-CompletionText "Uninstall-MtPack -PackLock '$script:lockFile' -Id "
            $offered | Should -Contain 'contoso.sample'
            $offered | Should -Not -Contain 'maester.zero-trust-assessment'
        }

        It 'completes the services of Connect-Maester' {
            Get-CompletionText 'Connect-Maester -Service Ex' | Should -Be @('ExchangeOnline')
        }

        It 'completes setting names' {
            Get-CompletionText 'Get-MtSetting -Name GitHubOrg' | Should -Be @('GitHubOrganization')
        }

        It 'completes role names, which the module defines privately' {
            Get-CompletionText 'Get-MtRoleMember -Role GlobalAdmin' | Should -Contain 'GlobalAdministrator'
        }
    }

    Context 'Quoting and safety' {
        It 'gives completion texts that parse back to the value' {
            $problems = InModuleScope Maester {
                foreach ($kind in 'Product', 'Feature', 'Area', 'Suite', 'Tag', 'TestId') {
                    foreach ($c in @(Get-MtCompletionCandidate -Kind $kind -CommandName 'Invoke-Maester')) {
                        $text = (ConvertTo-MtCompletionResult -Value $c.Value).CompletionText
                        $ast = [System.Management.Automation.Language.Parser]::ParseInput("x -P $text", [ref] $null, [ref] $null)
                        $argument = $ast.EndBlock.Statements[0].PipelineElements[0].CommandElements[2]
                        if (-not ($argument -is [System.Management.Automation.Language.StringConstantExpressionAst] -and $argument.Value -eq $c.Value)) { "$kind $($c.Value) -> $text" }
                    }
                }
            }
            $problems | Should -BeNullOrEmpty
        }

        It 'returns nothing and writes nothing when a source fails' {
            InModuleScope Maester {
                Mock Get-MtCompletionIndex { throw 'The catalogue could not be read.' }
                # Everything it returns or writes to the error and warning streams.
                $output = @(Get-MtArgumentCompletion -CommandName 'Invoke-Maester' -ParameterName 'TestId' -WordToComplete 'MT' 2>&1 3>&1)
                $output | Should -BeNullOrEmpty
            }
        }
    }
}
