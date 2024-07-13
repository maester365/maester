BeforeDiscovery {
    $module = 'Maester'
    $moduleRoot = "$PSScriptRoot/../.."
    # Get all the functions in the /public folder
    $functions = Get-ChildItem -Path "$moduleRoot/public" -Filter '*.ps1' | ForEach-Object { $_.BaseName }

    # Eventually this should include all functions in the /public folder
    # For now, just the ones that we have tested and added
    $functionsWithTests = @('Invoke-MtMaester')
}

Describe "$module Help Tests" -Tags ('Unit', 'Acceptance') -ForEach @{ moduleRoot = $moduleRoot } {
    Context 'Function <_>' -ForEach $functions {
        BeforeAll {
            $function = $_
            $functionPath = Join-Path -Path $moduleRoot -ChildPath "/public/$function.ps1"
        }

        It "<function>.ps1 should exist" {
            Join-Path -Path $moduleRoot -ChildPath "/public/$function.ps1"
            $functionPath | Should -Exist
        }

        It "<function>.ps1 should have help block" {
            $functionPath | Should -FileContentMatch '<#'
            $functionPath | Should -FileContentMatch '#>'
        }

        It "<function>.ps1 should have a SYNOPSIS section in the help block" {
            $functionPath | Should -FileContentMatch '.SYNOPSIS'
        }

        It "<function>.ps1 should have a DESCRIPTION section in the help block" {
            $functionPath | Should -FileContentMatch '.DESCRIPTION'
        }

        It "<function>.ps1 should have a EXAMPLE section in the help block" {
            $functionPath | Should -FileContentMatch '.EXAMPLE'
        }

        It "<function>.ps1 should be an advanced function" {
            $functionPath | Should -FileContentMatch 'function'
            $functionPath | Should -FileContentMatch 'cmdletbinding'
            $functionPath | Should -FileContentMatch 'param'
        }

        It "<function>.ps1 should contain Write-Verbose blocks" {
            $functionPath | Should -FileContentMatch 'Write-Verbose'
        }

        It "<function>.ps1 is valid PowerShell code" {
            $psFile = Get-Content -Path $functionPath -ErrorAction Stop
            $errors = $null
            $null = [System.Management.Automation.PSParser]::Tokenize($psFile, [ref]$errors)
            $errors.Count | Should -Be 0
        }

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