# Generated on 01/19/2025 07:06:36 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA118", "EXO", "Security", "All" {
    It "ORCA118: Domain Allow Listing" {
        $result = Test-ORCA118

        if($null -ne $result) {
            $result | Should -Be $true -Because "Your own domains are not being allow listed in an unsafe manner"
        }
    }
}
