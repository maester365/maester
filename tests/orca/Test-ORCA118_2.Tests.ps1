# Generated on 08/10/2025 15:41:31 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA.118.2", "EXO", "Security" {
    It "ORCA.118.2: Domains are not being allow listed in an unsafe manner in Transport Rules." {
        $result = Test-ORCA118_2

        if($null -ne $result) {
            $result | Should -Be $true -Because "Domains are not being allow listed in an unsafe manner in Transport Rules."
        }
    }
}
