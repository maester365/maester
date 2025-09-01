# Generated on 08/10/2025 15:41:31 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA.118.3", "EXO", "Security" {
    It "ORCA.118.3: Your own domains are not being allow listed in an unsafe manner in Anti-Spam Policies." {
        $result = Test-ORCA118_3

        if($null -ne $result) {
            $result | Should -Be $true -Because "Your own domains are not being allow listed in an unsafe manner in Anti-Spam Policies."
        }
    }
}
