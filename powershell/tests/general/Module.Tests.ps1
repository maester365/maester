BeforeAll {
    $module = 'Maester'
    $moduleRoot = (Resolve-Path "$global:testroot/..").Path
}

Describe -Tags ('Unit', 'Acceptance') "$module Module Tests" {

    Context 'Module Setup' {
        It "has the root module $module.psm1" {
            "$moduleRoot/$module.psm1" | Should -Exist
        }

        It "has the a manifest file of $module.psd1" {
            "$moduleRoot/$module.psd1" | Should -Exist
            "$moduleRoot/$module.psd1" | Should -FileContentMatch "$module.psm1"
        }

        It "$module folder has functions" {
            "$moduleRoot/public/*.ps1" | Should -Exist
        }

        It "$module is valid PowerShell code" {
            $psFile = Get-Content -Path "$moduleRoot\$module.psm1" `
                -ErrorAction Stop
            $errors = $null
            $null = [System.Management.Automation.PSParser]::Tokenize($psFile, [ref]$errors)
            $errors.Count | Should -Be 0
        }

    } # Context 'Module Setup'
}