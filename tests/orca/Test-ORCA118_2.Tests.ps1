# Generated on 03/04/2025 09:42:23 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA118_2", "EXO", "Security", "All" {
    It "ORCA118_2: Domains are not being allow listed in an unsafe manner in Transport Rules." {
        $result = Test-ORCA118_2

        if($null -ne $result) {
            $result | Should -Be $true -Because "Domains are not being allow listed in an unsafe manner in Transport Rules."
        }
    }
}
