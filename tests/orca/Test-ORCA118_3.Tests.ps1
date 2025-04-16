# Generated on 04/16/2025 21:38:23 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA.118.3", "EXO", "Security", "All" {
    It "ORCA.118.3: Your own domains are not being allow listed in an unsafe manner in Anti-Spam Policies." {
        $result = Test-ORCA118_3

        if($null -ne $result) {
            $result | Should -Be $true -Because "Your own domains are not being allow listed in an unsafe manner in Anti-Spam Policies."
        }
    }
}
