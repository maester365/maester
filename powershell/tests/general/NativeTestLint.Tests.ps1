BeforeDiscovery {
    $repoRoot = (Resolve-Path "$PSScriptRoot/../../..").Path
    $script:NativeFiles = @(Get-ChildItem -Path (Join-Path $repoRoot 'tests') -Recurse -File -Filter 'Test.*.ps1' |
            Where-Object { $_.FullName -notmatch '[\\/]Custom[\\/]' } |
            ForEach-Object { @{ Name = $_.Name; Path = $_.FullName } })
}

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
Describe 'Native built-in test <Name>' -ForEach $NativeFiles {
    BeforeAll {
        $script:function = Get-TestFunction -Path $Path
        $script:test = InModuleScope Maester -Parameters @{ P = $Path } { Read-MtNativeTest -Path $P }
    }

    It 'Is a valid native test' {
        $script:function | Should -Not -BeNullOrEmpty
        $script:test.Errors | Should -HaveCount 0 -Because (($script:test.Errors | ForEach-Object { "$($_.Code): $($_.Message)" }) -join '; ')
    }

    It 'Describes every parameter' {
        $missing = @($script:test.Parameters | Where-Object { -not $_.Description } | ForEach-Object { $_.Name })
        $missing | Should -BeNullOrEmpty -Because 'the run config reference and Get-MtTest show the description'
    }

    It 'Does not check its own connection' {
        $calls = @($script:function.Body.FindAll({
                    param($n)
                    $n -is [System.Management.Automation.Language.CommandAst] -and $n.GetCommandName() -eq 'Test-MtConnection'
                }, $true) | ForEach-Object { $_.Extent.Text })
        $calls | Should -BeNullOrEmpty -Because 'the Service property makes the engine skip the test when the service is not connected'
    }

    It 'Does not check its own licence' {
        # Tests whose licence need is not one License list for every run (a family where only some
        # instances need a premium licence) keep their own check.
        $allowed = @(
            'MT.1024' # Entra recommendations: only the premium recommendation instances need Entra ID P2.
        )
        if ($script:test.Id -in $allowed) { return }
        $text = $script:function.Body.Extent.Text
        $call = [regex]::Match($text, '\bGet-MtLicenseInformation\b')
        $skip = if ($call.Success) { [regex]::Match($text.Substring($call.Index), '-SkippedBecause\s+[''"]?NotLicensed\w*') }
        $skip.Success | Should -BeFalse -Because 'License makes the engine skip the test when the tenant is not licensed; add the ID to the allow-list only when the licence need varies by instance or the result branches on the plan'
    }

    It 'Does not catch every exception only to report -SkippedBecause Error' {
        # A catch that handles a specific case (403 -> NotAuthorized, then Error otherwise) is fine.
        $catches = @($script:function.Body.FindAll({
                    param($n)
                    $n -is [System.Management.Automation.Language.CatchClauseAst] -and $n.CatchTypes.Count -eq 0 -and
                    $n.Body.Extent.Text -match '^\{\s*Add-MtTestResultDetail\s+-SkippedBecause\s+Error(\s+-SkippedError\s+\$_)?\s*;?\s*(return(\s+\$null)?)?\s*;?\s*\}$'
                }, $true))
        $catches | Should -BeNullOrEmpty -Because 'the engine reports an exception as an Error row'
    }

    It 'Does not write script or global variables' {
        $writes = @($script:function.Body.FindAll({
                    param($n)
                    $n -is [System.Management.Automation.Language.AssignmentStatementAst] -and
                    $n.Left -is [System.Management.Automation.Language.VariableExpressionAst] -and
                    $n.Left.VariablePath.DriveName -in 'script', 'global'
                }, $true) | ForEach-Object { $_.Left.Extent.Text })
        $writes | Should -BeNullOrEmpty -Because 'tests can run in parallel; keep state in the session cache helpers'
    }

    It 'Declares Platform when it uses Windows-only commands' {
        # The ActiveDirectory service probe already skips these tests where the module is missing.
        if (@($script:test.Service) -contains 'ActiveDirectory') { return }
        $windowsOnly = @($script:function.Body.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] }, $true) |
                Where-Object { $_.GetCommandName() -match '^(Get-AD(User|Group|GroupMember|Computer|Domain|DomainController|Forest|Object|OrganizationalUnit|Trust|RootDSE|ServiceAccount|DefaultDomainPasswordPolicy|FineGrainedPasswordPolicy)|Get-GPO\w*|Get-WmiObject|Get-CimInstance)$' })
        if ($windowsOnly) { @($script:test.Platform) | Should -Contain 'Windows' }
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

# Product names come from one list, Products in powershell/assets/MaesterTestSchema.psd1. A new product is a
# deliberate addition to that list (and to the folder map below), never a new spelling in one test.
Describe 'Product of the built-in tests' {
    BeforeAll {
        $script:repoRoot = (Resolve-Path "$PSScriptRoot/../../..").Path
        $script:products = @(InModuleScope Maester { (Get-MtTestSchema).Products })
        $script:builtIn = @(Get-MtTest | Where-Object BuiltIn)

        # The product of every test in a folder that is named after a service or a suite of one product.
        # tests/cis is one folder for many products, so it is only checked against the list.
        $script:folderProduct = [ordered]@{
            'maester/azure'                = 'Azure'
            'maester/azure-devops'         = 'Azure DevOps'
            'maester/copilot-studio'       = 'Copilot Studio'
            'maester/defender'             = 'Defender'
            'maester/drift'                = 'Microsoft 365'
            'maester/entra'                = 'Entra ID'
            'maester/exchange'             = 'Exchange Online'
            'maester/global-secure-access' = 'Entra ID'
            'maester/intune'               = 'Intune'
            'maester/purview'              = 'Purview'
            'maester/teams'                = 'Teams'
            'maester/xspm'                 = 'Defender'
            'cisa/entra'                   = 'Entra ID'
            'cisa/exchange'                = 'Exchange Online'
            'cisa/sharepoint'              = 'SharePoint'
            'ad'                           = 'Active Directory'
            'eidsca'                       = 'Entra ID'
            'orca'                         = 'Defender'
        }

        function Get-TestFolder {
            param([string] $File)
            $relative = [System.IO.Path]::GetRelativePath((Join-Path $script:repoRoot 'tests'), $File) -replace '\\', '/'
            Split-Path -Path $relative -Parent
        }
    }

    It 'Finds the built-in tests and the product list' {
        $script:builtIn.Count | Should -BeGreaterThan 700
        $script:products.Count | Should -BeGreaterThan 5
    }

    It 'Uses only products from the Maester list, with the same spelling and case' {
        $offenders = $script:builtIn | Where-Object { $_.Product -cnotin $script:products } |
            ForEach-Object { "$($_.Id): '$($_.Product)'" }
        $offenders | Should -BeNullOrEmpty -Because "Product must be one of: $($script:products -join ', ')"
    }

    It 'Keeps the product list clean: no blanks, no duplicates, no unused names' {
        $script:products | Where-Object { $_ -ne $_.Trim() -or -not $_ } | Should -BeNullOrEmpty -Because 'a name has leading or trailing spaces'
        ($script:products | Group-Object { $_.ToLowerInvariant() } | Where-Object Count -GT 1).Name | Should -BeNullOrEmpty -Because 'two names differ only in case'
        $used = @($script:builtIn.Product | Select-Object -Unique)
        $script:products | Where-Object { $_ -cnotin $used } | Should -BeNullOrEmpty -Because 'a product no test uses should be removed from the list'
    }

    It 'Lists only products from the Maester list in the folder map' {
        $script:folderProduct.Values | Where-Object { $_ -cnotin $script:products } | Should -BeNullOrEmpty
    }

    It 'Gives every test in a service folder the product of that folder' {
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
