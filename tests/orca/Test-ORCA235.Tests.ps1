# Generated on 01/18/2025 19:34:47 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA235", "EXO", "Security", "All" {
    It "ORCA235: SPF Records" {
        $result = Test-ORCA235

        if($null -ne $result) {
            $result | Should -Be $true -Because "SPF records is set up for all your custom domains"
        }
    }
}
