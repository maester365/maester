# Generated on 08/10/2025 15:41:31 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA.118.1", "EXO", "Security", "All" {
    It "ORCA.118.1: Domains are not being allow listed in an unsafe manner in Anti-Spam Policies." {
        $result = Test-ORCA118_1

        if($null -ne $result) {
            $result | Should -Be $true -Because "Domains are not being allow listed in an unsafe manner in Anti-Spam Policies."
        }
    }
}
