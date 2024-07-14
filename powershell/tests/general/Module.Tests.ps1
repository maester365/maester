BeforeAll {
    $module = 'Maester'
    $moduleRoot = "$PSScriptRoot/../.."
}

Describe "<module> Module Tests" -Tags ('Unit', 'Acceptance') {
    Context 'Module Setup' {
        It "has the root module $module.psm1" {
            Join-Path -Path $moduleRoot -ChildPath "$module.psm1" | Should -Exist
        }

        It "has the a manifest file of $module.psd1" {
            Join-Path -Path $moduleRoot -ChildPath "$module.psd1" | Should -Exist
            Join-Path -Path $moduleRoot -ChildPath "$module.psd1" | Should -FileContentMatch "$module.psm1"
        }

        It '<module> folder has functions' {
            Join-Path -Path $moduleRoot -ChildPath "public/*.ps1" | Should -Exist
        }

        It '<module> is valid PowerShell code' {
            $psFile = Get-Content -Path (Join-Path -Path $moduleRoot -ChildPath "$module.psm1") -ErrorAction Stop
            $errors = $null
            $null = [System.Management.Automation.PSParser]::Tokenize($psFile, [ref]$errors)
            $errors.Count | Should -Be 0
        }

    } # Context 'Module Setup'
}