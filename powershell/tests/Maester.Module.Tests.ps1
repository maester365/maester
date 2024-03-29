BeforeAll {
    $here = $here = Split-Path -Parent $PSScriptRoot
    $module = 'Maester'
}

BeforeDiscovery {

    $functions = ('Invoke-MtMaester',
        'Connect-MtGraph'
        #     'Send-MtSummaryMail'
    )
}

Describe -Tags ('Unit', 'Acceptance') "$module Module Tests" {

    Context 'Module Setup' {
        It "has the root module $module.psm1" {
            "$here/$module.psm1" | Should -Exist
        }

        It "has the a manifest file of $module.psd1" {
            "$here/$module.psd1" | Should -Exist
            "$here/$module.psd1" | Should -FileContentMatch "$module.psm1"
        }

        It "$module folder has functions" {
            "$here/public/*.ps1" | Should -Exist
        }

        It "$module is valid PowerShell code" {
            $psFile = Get-Content -Path "$here\$module.psm1" `
                -ErrorAction Stop
            $errors = $null
            $null = [System.Management.Automation.PSParser]::Tokenize($psFile, [ref]$errors)
            $errors.Count | Should -Be 0
        }

    } # Context 'Module Setup'

    Context "Test Function" -ForEach $_functions {

        It "$_.ps1 should exist" {
            "$here/public/$_.ps1" | Should -Exist
        }

        It "$_.ps1 should have help block" {
            "$here/public/$_.ps1" | Should -FileContentMatch '<#'
            "$here/public/$_.ps1" | Should -FileContentMatch '#>'
        }

        It "$_.ps1 should have a SYNOPSIS section in the help block" {
            "$here/public/$_.ps1" | Should -FileContentMatch '.SYNOPSIS'
        }

        It "$_.ps1 should have a DESCRIPTION section in the help block" {
            "$here/public/$_.ps1" | Should -FileContentMatch '.DESCRIPTION'
        }

        # It "$_.ps1 should have a EXAMPLE section in the help block" {
        #     foreach ($_ in $_s) {
        #         "$here/public/$_.ps1" | Should -FileContentMatch '.EXAMPLE'
        #     }
        # }

        # It "$_.ps1 should be an advanced function" {
        #     foreach ($_ in $_s) {
        #         "$here/public/$_.ps1" | Should -FileContentMatch 'function'
        #         "$here/public/$_.ps1" | Should -FileContentMatch 'cmdletbinding'
        #         "$here/public/$_.ps1" | Should -FileContentMatch 'param'
        #     }

        # }

        # It "$_.ps1 should contain Write-Verbose blocks" {
        #     foreach ($_ in $_s) {
        #         "$here/public/$_.ps1" | Should -FileContentMatch 'Write-Verbose'
        #     }
        # }

        # It "$_.ps1 is valid PowerShell code" {
        #     $psFile = Get-Content -Path "$here/public/$_.ps1" `
        #         -ErrorAction Stop
        #     $errors = $null
        #     $null = [System.Management.Automation.PSParser]::Tokenize($psFile, [ref]$errors)
        #     $errors.Count | Should -Be 0
        # }


    } # Context "Test Function $_"

    # Context "$_ has tests" {
    #     It "function-$($_).Tests.ps1 should exist" {
    #         "$here/public/$($_).Tests.ps1" | Should -Exist
    #     }
    # }
}