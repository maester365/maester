BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force -WarningAction SilentlyContinue

    function Get-TestFunction {
        param([string] $Path)
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$null, [ref]$null)
        $functions = @($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $false))
        # The test function is the one with the [MaesterTest] attribute.
        $functions | Where-Object { $_.Body.ParamBlock -and ($_.Body.ParamBlock.Attributes | Where-Object { $_.TypeName.Name -eq 'MaesterTest' }) } | Select-Object -First 1
    }
}

# Rules for built-in native tests (design section 6): the engine checks connections and licences and turns an
# exception into an Error row, so the tests do not repeat that. Custom tests are not linted.
# One It per rule over every file, naming the files that break it: one Describe per file made 5,000+ tests.
Describe 'Native built-in tests' {
    BeforeAll {
        $repoRoot = (Resolve-Path "$PSScriptRoot/../../..").Path
        $paths = @(Get-ChildItem -Path (Join-Path $repoRoot 'tests') -Recurse -File -Filter 'Test.*.ps1' |
                Where-Object { $_.FullName -notmatch '[\\/]Custom[\\/]' } | ForEach-Object { $_.FullName })
        $tests = InModuleScope Maester -Parameters @{ Paths = $paths } {
            param($Paths)
            $byPath = @{}
            foreach ($p in $Paths) { $byPath[$p] = Read-MtNativeTest -Path $p }
            $byPath
        }
        $script:files = foreach ($p in $paths) {
            [pscustomobject]@{ Name = Split-Path $p -Leaf; Function = Get-TestFunction -Path $p; Test = $tests[$p] }
        }
    }

    It 'Finds the built-in tests' {
        $script:files.Count | Should -BeGreaterThan 500
    }

    It 'Are valid native tests' {
        $problems = foreach ($f in $script:files) {
            if (-not $f.Function) { "$($f.Name): no function with a [MaesterTest] attribute" }
            foreach ($e in $f.Test.Errors) { "$($f.Name): $($e.Code): $($e.Message)" }
        }
        @($problems) | Should -BeNullOrEmpty
    }

    It 'Describe every parameter' {
        $problems = foreach ($f in $script:files) {
            $missing = @($f.Test.Parameters | Where-Object { -not $_.Description } | ForEach-Object { $_.Name })
            if ($missing) { "$($f.Name): $($missing -join ', ')" }
        }
        @($problems) | Should -BeNullOrEmpty -Because 'the run config reference and Get-MtTest show the description'
    }

    It 'Do not check their own connection' {
        $problems = foreach ($f in $script:files | Where-Object Function) {
            $f.Function.Body.FindAll({
                    param($n)
                    $n -is [System.Management.Automation.Language.CommandAst] -and $n.GetCommandName() -eq 'Test-MtConnection'
                }, $true) | ForEach-Object { "$($f.Name): $($_.Extent.Text)" }
        }
        @($problems) | Should -BeNullOrEmpty -Because 'the Service property makes the engine skip the test when the service is not connected'
    }

    It 'Do not check their own licence' {
        # Tests whose licence need is not one License list for every run (a family where only some
        # instances need a premium licence) keep their own check.
        $allowed = @(
            'MT.1024' # Entra recommendations: only the premium recommendation instances need Entra ID P2.
        )
        $problems = foreach ($f in $script:files | Where-Object Function) {
            if ($f.Test.Id -in $allowed) { continue }
            $text = $f.Function.Body.Extent.Text
            $call = [regex]::Match($text, '\bGet-MtLicenseInformation\b')
            if ($call.Success -and [regex]::Match($text.Substring($call.Index), '-SkippedBecause\s+[''"]?NotLicensed\w*').Success) { $f.Name }
        }
        @($problems) | Should -BeNullOrEmpty -Because 'License makes the engine skip the test when the tenant is not licensed; add the ID to the allow-list only when the licence need varies by instance or the result branches on the plan'
    }

    It 'Do not catch every exception only to report -SkippedBecause Error' {
        # A catch that handles a specific case (403 -> NotAuthorized, then Error otherwise) is fine.
        $problems = foreach ($f in $script:files | Where-Object Function) {
            $catches = @($f.Function.Body.FindAll({
                        param($n)
                        $n -is [System.Management.Automation.Language.CatchClauseAst] -and $n.CatchTypes.Count -eq 0 -and
                        $n.Body.Extent.Text -match '^\{\s*Add-MtTestResultDetail\s+-SkippedBecause\s+Error(\s+-SkippedError\s+\$_)?\s*;?\s*(return(\s+\$null)?)?\s*;?\s*\}$'
                    }, $true))
            if ($catches) { $f.Name }
        }
        @($problems) | Should -BeNullOrEmpty -Because 'the engine reports an exception as an Error row'
    }

    It 'Do not write script or global variables' {
        $problems = foreach ($f in $script:files | Where-Object Function) {
            $f.Function.Body.FindAll({
                    param($n)
                    $n -is [System.Management.Automation.Language.AssignmentStatementAst] -and
                    $n.Left -is [System.Management.Automation.Language.VariableExpressionAst] -and
                    ($n.Left.VariablePath.IsScript -or $n.Left.VariablePath.IsGlobal)
                }, $true) | ForEach-Object { "$($f.Name): $($_.Left.Extent.Text)" }
        }
        @($problems) | Should -BeNullOrEmpty -Because 'tests can run in parallel; keep state in the session cache helpers'
    }

    It 'Declare Platform when they use Windows-only commands' {
        $problems = foreach ($f in $script:files | Where-Object Function) {
            # The ActiveDirectory service probe already skips these tests where the module is missing.
            if (@($f.Test.Service) -contains 'ActiveDirectory') { continue }
            $windowsOnly = @($f.Function.Body.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] }, $true) |
                    Where-Object { $_.GetCommandName() -match '^(Get-AD(User|Group|GroupMember|Computer|Domain|DomainController|Forest|Object|OrganizationalUnit|Trust|RootDSE|ServiceAccount|DefaultDomainPasswordPolicy|FineGrainedPasswordPolicy)|Get-GPO\w*|Get-WmiObject|Get-CimInstance)$' })
            if ($windowsOnly -and @($f.Test.Platform) -notcontains 'Windows') { $f.Name }
        }
        @($problems) | Should -BeNullOrEmpty
    }
}

# The check helpers in internal/checks run inside a native test, so the engine has already checked the
# test's Service before they are called.
Describe 'Check helpers' {
    It 'Do not check their own connection' {
        $root = (Resolve-Path "$PSScriptRoot/../../internal/checks").Path
        $calls = @(Get-ChildItem -Path $root -Recurse -File -Filter '*.ps1' | ForEach-Object {
                $ast = [System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$null, [ref]$null)
                $file = $_.Name
                $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] -and $n.GetCommandName() -eq 'Test-MtConnection' }, $true) |
                    ForEach-Object { "$($file): $($_.Extent.Text)" }
            })
        $calls | Should -BeNullOrEmpty -Because 'declare the service in the calling test''s Service property instead'
    }
}

# Products come from one list, Products in powershell/assets/MaesterTaxonomy.psd1. A test names its product by
# key. A new product is a deliberate addition to that list (and to the folder map below), never a new
# spelling in one test.
Describe 'Product of the built-in tests' {
    BeforeAll {
        $script:repoRoot = (Resolve-Path "$PSScriptRoot/../../..").Path
        $script:taxonomy = Import-PowerShellDataFile -Path (Join-Path $script:repoRoot 'powershell/assets/MaesterTaxonomy.psd1')
        $script:products = @($script:taxonomy.Products | ForEach-Object { $_.Key })
        $script:builtIn = @(Get-MtTest | Where-Object BuiltIn)

        # The product of every test in a folder that is named after a service or a suite of one product.
        # tests/cis is one folder for many products, so it is only checked against the list.
        $script:folderProduct = [ordered]@{
            'maester/azure'                = 'azure'
            'maester/azure-devops'         = 'azure-devops'
            'maester/copilot-studio'       = 'copilot-studio'
            'maester/defender'             = 'defender'
            'maester/drift'                = 'microsoft-365'
            'maester/entra'                = 'entra'
            'maester/exchange'             = 'exchange'
            'maester/global-secure-access' = 'entra'
            'maester/intune'               = 'intune'
            'maester/purview'              = 'purview'
            'maester/teams'                = 'teams'
            'maester/xspm'                 = 'defender'
            'cisa/entra'                   = 'entra'
            'cisa/exchange'                = 'exchange'
            'cisa/sharepoint'              = 'sharepoint'
            'asd/entra'                    = 'entra'
            'asd/intune'                   = 'intune'
            'ad'                           = 'ad'
            'eidsca'                       = 'entra'
            'orca'                         = 'defender'
        }

        function Get-TestFolder {
            param([string] $File)
            # Forward slashes on every platform (Split-Path would turn them back into backslashes on Windows).
            $relative = [System.IO.Path]::GetRelativePath((Join-Path $script:repoRoot 'tests'), $File) -replace '\\', '/'
            $cut = $relative.LastIndexOf('/')
            if ($cut -lt 0) { '' } else { $relative.Substring(0, $cut) }
        }
    }

    It 'Finds the built-in tests and the product list' {
        $script:builtIn.Count | Should -BeGreaterThan 700
        $script:products.Count | Should -BeGreaterThan 5
    }

    It 'Stores the product of every built-in test as a key of the taxonomy registry' {
        $offenders = $script:builtIn | Where-Object { $_.Product -cnotin $script:products } |
            ForEach-Object { "$($_.Id): '$($_.Product)'" }
        $offenders | Should -BeNullOrEmpty -Because "Product must be one of: $($script:products -join ', ')"
    }

    It 'Writes the product as its key in the test file, not as an alias' {
        # An alias such as 'Entra ID' loads, but the built-in tests are the examples that contributors copy.
        $offenders = foreach ($test in $script:builtIn) {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($test.File, [ref] $null, [ref] $null)
            $attribute = $ast.Find({ param($n) $n -is [System.Management.Automation.Language.AttributeAst] -and $n.TypeName.Name -eq 'MaesterTest' }, $true)
            $written = ($attribute.NamedArguments | Where-Object ArgumentName -EQ 'Product').Argument.Value
            if ($written -cnotin $script:products) { "$($test.Id): '$written'" }
        }
        $offenders | Should -BeNullOrEmpty -Because 'run ./build/migration/Convert-MtTestAttributes.ps1, or write the key from powershell/assets/MaesterTaxonomy.psd1'
    }

    It 'Keeps the product list clean: lowercase kebab-case keys, no duplicates, no unused product' {
        $script:products | Where-Object { $_ -cnotmatch '^[a-z0-9]+(-[a-z0-9]+)*$' } | Should -BeNullOrEmpty -Because 'a product key is lowercase kebab-case'
        ($script:products | Group-Object | Where-Object Count -GT 1).Name | Should -BeNullOrEmpty -Because 'a key is listed twice'
        $owners = @{}
        foreach ($product in $script:taxonomy.Products) {
            foreach ($name in @($product.Key) + @($product.Aliases)) { $owners[$name.ToLowerInvariant()] = @($owners[$name.ToLowerInvariant()]) + $product.Key | Where-Object { $_ } | Select-Object -Unique }
        }
        @($owners.Keys | Where-Object { @($owners[$_]).Count -gt 1 }) | Should -BeNullOrEmpty -Because 'a key or alias must name one product only, whatever its case'
        $used = @($script:builtIn.Product | Select-Object -Unique)
        $script:products | Where-Object { $_ -cnotin $used } | Should -BeNullOrEmpty -Because 'a product no test uses should be removed from the list'
    }

    It 'Lists only products from the taxonomy registry in the folder map' {
        $script:folderProduct.Values | Where-Object { $_ -cnotin $script:products } | Should -BeNullOrEmpty
    }

    It 'Gives every test in a service folder the product of that folder' {
        # Guard against a path bug that makes this check skip every test.
        @($script:builtIn | Where-Object { $script:folderProduct.Contains((Get-TestFolder -File $_.File)) }).Count | Should -BeGreaterThan 300
        (Get-TestFolder -File ($script:builtIn | Where-Object Id -EQ 'MT.1001').File) | Should -Be 'maester/entra'
        $offenders = foreach ($test in $script:builtIn) {
            $folder = Get-TestFolder -File $test.File
            # The folder itself, or its suite for suites with area subfolders (ad/user -> ad).
            $key = if ($script:folderProduct.Contains($folder)) { $folder } else { ($folder -split '/')[0] }
            if (-not $script:folderProduct.Contains($key)) { continue }
            if ($test.Product -cne $script:folderProduct[$key]) { "$($test.Id) in tests/${folder}: '$($test.Product)', expected '$($script:folderProduct[$key])'" }
        }
        $offenders | Should -BeNullOrEmpty -Because 'the folder names the product (see the repository layout in the contributing guide)'
    }

    It 'Has a product in the folder map for every service folder' {
        $missing = $script:builtIn | ForEach-Object { Get-TestFolder -File $_.File } | Select-Object -Unique |
            Where-Object { $_ -ne 'cis' -and -not $script:folderProduct.Contains($_) -and -not $script:folderProduct.Contains(($_ -split '/')[0]) }
        $missing | Should -BeNullOrEmpty -Because 'a new test folder needs its product in the folder map of this test'
    }
}
