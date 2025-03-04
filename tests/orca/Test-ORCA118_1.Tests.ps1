# Generated on 03/04/2025 10:12:40 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA118_1", "EXO", "Security", "All" {
    It "ORCA118_1: Domains are not being allow listed in an unsafe manner in Anti-Spam Policies." {
        $result = Test-ORCA118_1

        if($null -ne $result) {
            $result | Should -Be $true -Because "Domains are not being allow listed in an unsafe manner in Anti-Spam Policies."
        }
    }
}
