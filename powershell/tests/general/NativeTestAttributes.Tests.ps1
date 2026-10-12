# The mechanical half of the attribute rubric (website/docs/writing-tests/attribute-rubric.md): every built-in
# test declares what it is about, how urgent a failure is and what it maps to, with keys from the taxonomy
# registry. Whether a value is the right one is a judgement; the attribute-review workflow and the reviewer check
# that. Custom tests are not checked here.

BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force -WarningAction SilentlyContinue
    $script:repoRoot = (Resolve-Path "$PSScriptRoot/../../..").Path

    $files = @(Get-ChildItem -Path (Join-Path $script:repoRoot 'tests') -Recurse -File -Filter 'Test.*.ps1' |
            Where-Object { $_.FullName -notmatch '[\\/]custom[\\/]' })
    $script:tests = @(InModuleScope Maester -Parameters @{ Files = $files.FullName } {
            foreach ($file in $Files) { [pscustomobject](Read-MtNativeTest -Path $file -BuiltIn) }
        })
    $script:taxonomy = InModuleScope Maester { Get-MtTaxonomy }
    $script:areaKeys = @($script:taxonomy.Areas.Key)
    $script:resourceTypeKeys = @($script:taxonomy.ResourceTypes.Key)
    $script:productKeys = @($script:taxonomy.Products.Key)
    $script:featuresOf = @{}
    foreach ($product in $script:taxonomy.Products) { $script:featuresOf[$product.Key] = @($product.Features.Key) }

    # Reports offenders as "ID: detail" so a failure names every test to fix.
    function Get-Offender {
        param([scriptblock] $Where, [scriptblock] $Detail = { '' })
        @($script:tests | Where-Object $Where | ForEach-Object {
                $detail = & $Detail $_
                if ($detail) { "$($_.Id): $detail" } else { $_.Id }
            })
    }
}

Describe 'Attributes of the built-in tests' {
    It 'Finds the built-in tests and the taxonomy' {
        $script:tests.Count | Should -BeGreaterThan 700
        $script:areaKeys.Count | Should -BeGreaterThan 5
        $script:resourceTypeKeys | Should -Contain 'Tenant'
    }

    Context 'What the test is about' {
        It 'Declares Feature, Area and ResourceType' {
            $offenders = Get-Offender { -not $_.Feature -or -not $_.Area -or -not $_.ResourceType } {
                param($t) (@('Feature', 'Area', 'ResourceType') | Where-Object { -not $t.$_ }) -join ', '
            }
            $offenders | Should -BeNullOrEmpty -Because 'every built-in test says what it is about (see the attribute rubric)'
        }

        It 'Uses a feature that belongs to its product' {
            $offenders = Get-Offender { $_.Feature -and $_.Feature -cnotin $script:featuresOf[$_.Product] } {
                param($t) "'$($t.Feature)' is not a feature of '$($t.Product)'"
            }
            $offenders | Should -BeNullOrEmpty -Because 'a feature key is scoped to its product in powershell/assets/MaesterTaxonomy.psd1'
        }

        It 'Uses an area from the taxonomy' {
            $offenders = Get-Offender { $_.Area -and $_.Area -cnotin $script:areaKeys } { param($t) "'$($t.Area)'" }
            $offenders | Should -BeNullOrEmpty -Because "Area must be one of: $($script:areaKeys -join ', ')"
        }

        It 'Uses a resource type from the taxonomy' {
            $offenders = Get-Offender { $_.ResourceType -and $_.ResourceType -cnotin $script:resourceTypeKeys } { param($t) "'$($t.ResourceType)'" }
            $offenders | Should -BeNullOrEmpty -Because "ResourceType must be one of: $($script:resourceTypeKeys -join ', ')"
        }

        It 'Lists related products that exist and are not the product itself' {
            $offenders = Get-Offender {
                @($_.RelatedProduct | Where-Object { $_ }).Count -gt 0 -and (
                    @($_.RelatedProduct | Where-Object { $_ -cnotin $script:productKeys }).Count -gt 0 -or $_.Product -in $_.RelatedProduct -or
                    @($_.RelatedProduct | Select-Object -Unique).Count -ne @($_.RelatedProduct).Count)
            } { param($t) "RelatedProduct = $($t.RelatedProduct -join ', ')" }
            $offenders | Should -BeNullOrEmpty -Because 'RelatedProduct holds product keys other than Product, each once'
        }
    }

    Context 'What to fix first' {
        It 'Rates UserImpact and ImplementationCost on every test that is not Info' {
            $offenders = Get-Offender { $_.Severity -ne 'Info' -and (-not $_.UserImpact -or -not $_.ImplementationCost) } {
                param($t) (@('UserImpact', 'ImplementationCost') | Where-Object { -not $t.$_ }) -join ', '
            }
            $offenders | Should -BeNullOrEmpty -Because 'a test that can fail on risk says how disruptive and how costly the fix is'
        }

        It 'Leaves UserImpact and ImplementationCost off Info tests' {
            $offenders = Get-Offender { $_.Severity -eq 'Info' -and ($_.UserImpact -or $_.ImplementationCost) }
            $offenders | Should -BeNullOrEmpty -Because 'an Info test reports a fact and has no fix to rate'
        }
    }

    Context 'What it maps to' {
        It 'Declares Mitre as technique IDs or None' {
            $offenders = Get-Offender { @($_.Mitre | Where-Object { $_ }).Count -eq 0 }
            $offenders | Should -BeNullOrEmpty -Because "a test with no technique behind it says Mitre = 'None', so a missing value is never a forgotten one"
        }

        It 'Names only techniques of the pinned ATT&CK release' {
            $offenders = @(foreach ($test in $script:tests) {
                    $problems = @(InModuleScope Maester -Parameters @{ Mitre = [string[]]@($test.Mitre) } { Get-MtAttackTechniqueProblem -Mitre $Mitre })
                    if ($problems.Count -gt 0) { "$($test.Id): $($problems -join ' ')" }
                })
            $offenders | Should -BeNullOrEmpty -Because 'see build/attack/Update-MtAttackTechniques.ps1 for moving the pin'
        }

        It 'Does not combine None with a technique or list more than five' {
            $offenders = Get-Offender {
                $ids = @($_.Mitre | Where-Object { $_ -and $_ -ne 'None' })
                ($_.Mitre -contains 'None' -and $ids.Count -gt 0) -or $ids.Count -gt 5 -or @($ids | Select-Object -Unique).Count -ne $ids.Count
            } { param($t) "Mitre = $($t.Mitre -join ', ')" }
            $offenders | Should -BeNullOrEmpty
        }

        It 'Does not list a technique beside one of its own sub-techniques' {
            $offenders = Get-Offender {
                $ids = @($_.Mitre | Where-Object { $_ -match '^T\d{4}' })
                $parents = @($ids | Where-Object { $_ -notmatch '\.' })
                @($ids | Where-Object { $_ -match '\.' -and ($_ -split '\.')[0] -in $parents }).Count -gt 0
            } { param($t) "Mitre = $($t.Mitre -join ', ')" }
            $offenders | Should -BeNullOrEmpty -Because 'list the technique or its sub-technique, not both'
        }

        It 'Lists the technique when three or more of its sub-techniques apply' {
            $offenders = Get-Offender {
                $subs = @($_.Mitre | Where-Object { $_ -match '^T\d{4}\.' } | ForEach-Object { ($_ -split '\.')[0] })
                @($subs | Group-Object | Where-Object Count -GE 3).Count -gt 0
            } { param($t) "Mitre = $($t.Mitre -join ', ')" }
            $offenders | Should -BeNullOrEmpty
        }

        Context 'Frameworks' {
            BeforeAll {
                # <framework-key> -> the requirement IDs of its framework file, and the suites that declare frameworks.
                $script:requirementsOf = @{}
                $script:frameworkSuites = @(foreach ($manifest in (Get-ChildItem -Path (Join-Path $script:repoRoot 'tests') -Recurse -File -Filter 'suite.json')) {
                        $suite = Get-Content $manifest.FullName -Raw | ConvertFrom-Json
                        if (-not $suite.PSObject.Properties['Frameworks']) { continue }
                        $keys = @(foreach ($declared in @($suite.Frameworks)) {
                                if (-not $declared) { continue }
                                $file = Join-Path $manifest.Directory.FullName "frameworks/$($declared.Key).json"
                                $script:requirementsOf[$declared.Key] = @((Get-Content $file -Raw | ConvertFrom-Json).Requirements.Id)
                                $declared.Key
                            })
                        [pscustomobject]@{ Id = $suite.Id; Folder = $manifest.Directory.FullName + [System.IO.Path]::DirectorySeparatorChar; Keys = $keys }
                    })
            }

            It 'Finds the suites that declare frameworks' {
                @($script:frameworkSuites.Id | Sort-Object) | Should -Be @('CIS', 'CISA')
                @($script:requirementsOf.Keys | Sort-Object) | Should -Be @('cis-github', 'cis-m365', 'cisa-scuba')
            }

            It 'Names an existing requirement when a Control refers to a framework shipped with Maester' {
                $offenders = foreach ($test in $script:tests) {
                    foreach ($control in @($test.Control | Where-Object { $_ })) {
                        $key, $requirement = $control -split ':', 2
                        if ($script:requirementsOf.ContainsKey($key) -and $requirement -cnotin $script:requirementsOf[$key]) { "$($test.Id): $control is not a requirement of $key" }
                    }
                }
                $offenders | Should -BeNullOrEmpty -Because 'add the requirement to the framework file, or correct the Control'
            }

            It 'Maps every test of a suite that declares frameworks to a requirement of one of them' {
                $offenders = foreach ($suite in $script:frameworkSuites) {
                    foreach ($test in ($script:tests | Where-Object { $_.File.StartsWith($suite.Folder, [System.StringComparison]::OrdinalIgnoreCase) })) {
                        $mapped = @($test.Control | Where-Object {
                                $key, $requirement = $_ -split ':', 2
                                $key -cin $suite.Keys -and $requirement -cin $script:requirementsOf[$key]
                            })
                        if ($mapped.Count -eq 0) { "$($test.Id): no Control names a requirement of $($suite.Keys -join ' or ')" }
                    }
                }
                $offenders | Should -BeNullOrEmpty -Because "a test in a benchmark suite says which requirement it implements, for example Control = 'cis-m365:5.1.5.1'"
            }
        }
    }

    Context 'Lifecycle' {
        It 'Gives ReplacedBy only on a deprecated test, and points it at a test that exists' {
            $ids = @($script:tests.Id)
            $offenders = Get-Offender { $_.ReplacedBy -and ($_.Lifecycle -ne 'Deprecated' -or $_.ReplacedBy -notin $ids) } { param($t) "ReplacedBy = $($t.ReplacedBy), Lifecycle = $($t.Lifecycle)" }
            $offenders | Should -BeNullOrEmpty
        }
    }

    Context 'Tags' {
        BeforeAll {
            # Everything a typed attribute or a derived value already says: taxonomy keys and names, suite names,
            # severities, and every tag Maester 2.x used.
            $reserved = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
            foreach ($product in $script:taxonomy.Products) {
                foreach ($value in @($product.Key, $product.Name) + @($product.Aliases) + @($product.Features.Key) + @($product.Features.Name)) { if ($value) { $null = $reserved.Add($value) } }
            }
            foreach ($value in @($script:taxonomy.Areas.Key) + @($script:taxonomy.Areas.Name) + @($script:taxonomy.ResourceTypes.Key)) { $null = $reserved.Add($value) }
            foreach ($value in 'Critical', 'High', 'Medium', 'Low', 'Info', 'Preview', 'Deprecated', 'Stable') { $null = $reserved.Add($value) }
            foreach ($suite in Get-ChildItem -Path (Join-Path $script:repoRoot 'tests') -Recurse -File -Filter 'suite.json') {
                $manifest = Get-Content -LiteralPath $suite.FullName -Raw | ConvertFrom-Json
                foreach ($name in 'Id', 'Name', 'Source') { if ($manifest.PSObject.Properties[$name] -and $manifest.$name) { $null = $reserved.Add([string]$manifest.$name) } }
            }
            $legacy = Get-Content -LiteralPath (Join-Path $script:repoRoot 'powershell/assets/Maester.LegacyTags.json') -Raw | ConvertFrom-Json
            foreach ($entry in $legacy.Tags) { $null = $reserved.Add([string]$entry.Tag) }
            foreach ($id in $script:tests.Id) { $null = $reserved.Add([string]$id) }
            $script:reservedTags = $reserved
        }

        It 'Carries no tag that an attribute or a derived value already says' {
            $offenders = Get-Offender {
                @($_.Tag | Where-Object { $_ -and ($script:reservedTags.Contains($_) -or $_ -match '^(Severity|Product|Feature|Area|Suite):') }).Count -gt 0
            } { param($t) "Tag = $($t.Tag -join ', ')" }
            $offenders | Should -BeNullOrEmpty -Because 'built-in tests do not tag product, feature, area, suite, benchmark, licence, severity or their own ID (see the rubric); use the attribute'
        }
    }
}

Describe 'Taxonomy registry' {
    It 'Uses lowercase kebab-case keys for products, features and areas, and PascalCase for resource types' {
        $kebab = '^[a-z0-9]+(-[a-z0-9]+)*$'
        $bad = @($script:productKeys) + @($script:taxonomy.Products.Features.Key) + @($script:areaKeys) | Where-Object { $_ -cnotmatch $kebab }
        $bad | Should -BeNullOrEmpty
        $script:resourceTypeKeys | Where-Object { $_ -cnotmatch '^[A-Z][A-Za-z0-9]*$' } | Should -BeNullOrEmpty
    }

    It 'Has no duplicate key' {
        ($script:productKeys | Group-Object | Where-Object Count -GT 1).Name | Should -BeNullOrEmpty
        ($script:areaKeys | Group-Object | Where-Object Count -GT 1).Name | Should -BeNullOrEmpty
        ($script:resourceTypeKeys | Group-Object | Where-Object Count -GT 1).Name | Should -BeNullOrEmpty
        foreach ($product in $script:taxonomy.Products) {
            ($product.Features.Key | Group-Object | Where-Object Count -GT 1).Name | Should -BeNullOrEmpty -Because "features of $($product.Key)"
        }
    }

    It 'Gives every product, feature and area a display name' {
        @($script:taxonomy.Products | Where-Object { -not $_.Name }).Key | Should -BeNullOrEmpty
        @($script:taxonomy.Products.Features | Where-Object { -not $_.Name }).Key | Should -BeNullOrEmpty
        @($script:taxonomy.Areas | Where-Object { -not $_.Name -or -not $_.Description }).Key | Should -BeNullOrEmpty
        @($script:taxonomy.ResourceTypes | Where-Object { -not $_.Description }).Key | Should -BeNullOrEmpty
    }

    It 'Has no feature, area or resource type that no test uses' {
        $usedFeatures = @($script:tests | ForEach-Object { "$($_.Product)/$($_.Feature)" } | Select-Object -Unique)
        $unusedFeatures = @(foreach ($product in $script:taxonomy.Products) { foreach ($key in $product.Features.Key) { if ("$($product.Key)/$key" -cnotin $usedFeatures) { "$($product.Key)/$key" } } })
        $unusedFeatures | Should -BeNullOrEmpty -Because 'a key that no test uses should be removed from the taxonomy'
        $script:areaKeys | Where-Object { $_ -cnotin @($script:tests.Area) } | Should -BeNullOrEmpty
        $script:resourceTypeKeys | Where-Object { $_ -cnotin @($script:tests.ResourceType) } | Should -BeNullOrEmpty
    }

    It 'Is described by the rubric: the area table lists exactly the areas of the registry' {
        $rubric = Get-Content -LiteralPath (Join-Path $script:repoRoot 'website/docs/writing-tests/attribute-rubric.md') -Raw
        $section = [regex]::Match($rubric, '(?s)## Area\r?\n(.*?)\r?\n## ').Groups[1].Value
        $documented = @([regex]::Matches($section, '(?m)^\| `([a-z0-9-]+)` \|') | ForEach-Object { $_.Groups[1].Value })
        ($documented | Sort-Object) -join ', ' | Should -Be (($script:areaKeys | Sort-Object) -join ', ') -Because 'the rubric and the registry describe the same areas'
    }
}
