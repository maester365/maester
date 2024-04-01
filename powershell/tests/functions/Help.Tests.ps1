BeforeAll {
    $module = 'Maester'
    $moduleRoot = (Resolve-Path "$global:testroot/..").Path
}

BeforeDiscovery {

    $moduleRoot = (Resolve-Path "$global:testroot/..").Path
    # Get all the functions in the /public folder
    $functions = Get-ChildItem -Path "$moduleRoot/public" -Filter '*.ps1' | ForEach-Object { $_.BaseName }

    # Eventually this should include all functions in the /public folder
    # For now, just the ones that we have tested and added
    $functionsWithTests = ('Invoke-MtMaester'
    )
}

Describe -Tags ('Unit', 'Acceptance') "$module Module Tests" {

    Context "Test Function" -ForEach $functions {

        It "$_.ps1 should exist" {
            "$moduleRoot/public/$_.ps1" | Should -Exist
        }

        It "$_.ps1 should have help block" {
            "$moduleRoot/public/$_.ps1" | Should -FileContentMatch '<#'
            "$moduleRoot/public/$_.ps1" | Should -FileContentMatch '#>'
        }

        It "$_.ps1 should have a SYNOPSIS section in the help block" {
            "$moduleRoot/public/$_.ps1" | Should -FileContentMatch '.SYNOPSIS'
        }

        It "$_.ps1 should have a DESCRIPTION section in the help block" {
            "$moduleRoot/public/$_.ps1" | Should -FileContentMatch '.DESCRIPTION'
        }

        It "$_.ps1 should have a EXAMPLE section in the help block" {
            "$moduleRoot/public/$_.ps1" | Should -FileContentMatch '.EXAMPLE'
        }

        It "$_.ps1 should be an advanced function" {
            foreach ($_ in $_s) {
                "$moduleRoot/public/$_.ps1" | Should -FileContentMatch 'function'
                "$moduleRoot/public/$_.ps1" | Should -FileContentMatch 'cmdletbinding'
                "$moduleRoot/public/$_.ps1" | Should -FileContentMatch 'param'
            }

        }

        It "$_.ps1 should contain Write-Verbose blocks" {
            "$moduleRoot/public/$_.ps1" | Should -FileContentMatch 'Write-Verbose'
        }

        It "$_.ps1 is valid PowerShell code" {
            $psFile = Get-Content -Path "$moduleRoot/public/$_.ps1" `
                -ErrorAction Stop
            $errors = $null
            $null = [System.Management.Automation.PSParser]::Tokenize($psFile, [ref]$errors)
            $errors.Count | Should -Be 0
        }

        It "$_ should run without exceptions" {
            $scriptBlock = [scriptblock]::Create((Get-Content "$moduleRoot/public/$_.ps1" -Raw))
            { & $scriptBlock } | Should -Not -Throw
        }
    }

    Context "Test Function" -ForEach $functionsWithTests {
        It "($_.Tests.ps1) should exist" {
            "$moduleRoot/tests/functions/$($_).Tests.ps1" | Should -Exist
        }
    }
}