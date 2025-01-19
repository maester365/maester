# Generated on 01/19/2025 05:57:38 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA235", "EXO", "Security", "All" {
    It "ORCA235: SPF Records" {
        $result = Test-ORCA235

        if($null -ne $result) {
            $result | Should -Be $true -Because "SPF records is set up for all your custom domains"
        }
    }
}
