BeforeDiscovery {
    $moduleName = 'Maester'
    $moduleRoot = "$PSScriptRoot/../.."
    # Get all the functions in the /public folder
    $exportedFunctions = Get-Command -Module $moduleName -CommandType Function

    # Eventually this should include all functions in the /public folder
    # For now, just the ones that we have tested and added
    $functionsWithTests = @('Invoke-Maester')
}

Describe 'Common function tests' -Tags 'Acceptance' -ForEach @{ exportedFunctions = $exportedFunctions; moduleRoot = $moduleRoot } {
    Context '<_.CommandType> <_.Name>' -ForEach $exportedFunctions {
        BeforeAll {
            $function = $_
            # Need to update this if we start building the module as a single psm1 file (for improved performance)
            $functionPath = $_.ScriptBlock.File
        }

        It "<function>.ps1 should exist in public folder" {
            # Normalize path in test to work cross-platform
            $functionPath -replace '\\','/' | Should -BeLike "*/public/*$($function.Name).ps1"
            $functionPath | Should -Exist
        }

        It "Should be an advanced function" {
            $function.CmdletBinding | Should -BeTrue -Because 'public functions should be advanced functions'
            $function.ScriptBlock.Ast.Body.ParamBlock | Should -Not -BeNullOrEmpty -Because 'functions should have a param()-block'
            $function.ScriptBlock.Ast.Body.ParamBlock | Should -Not -BeNullOrEmpty -Because 'functions should have [CmdletBinding()] attribute for explicit advanced function'
        }

        # Skipping for Cisa tests until they're updated
        It "Should contain Write-Verbose logging" -Skip:($_.Name -match 'Cisa') {
            $function.Definition -match 'Write-Verbose' | Should -BeTrue -Because 'we like information when troubleshooting'
        }

        # Not really necessary as we test exported commands meaning they were able to load
        It "<function>.ps1 is valid PowerShell code" {
            $psFile = Get-Content -Path $functionPath -ErrorAction Stop
            $errors = $null
            $null = [System.Management.Automation.PSParser]::Tokenize($psFile, [ref]$errors)
            $errors.Count | Should -Be 0
        }

        # Same comment as above, but doesn't hurt to double check
        It '<function>.ps1 should run without exceptions' {
            $scriptBlock = [scriptblock]::Create((Get-Content $functionPath -Raw))
            { & $scriptBlock } | Should -Not -Throw
        }

        # Intentionally using skip so the output will remind us of the missing test files :)
        It 'Matching test file file should exist' -Skip:$($_ -notin $functionsWithTests) {
            "$moduleRoot/tests/functions/$($_).Tests.ps1" | Should -Exist
        }
    }
}