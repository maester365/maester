# Generated on 03/04/2025 10:12:41 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA237", "EXO", "Security", "All" {
    It "ORCA237: Safe Links is enabled for teams messages." {
        $result = Test-ORCA237

        if($null -ne $result) {
            $result | Should -Be $true -Because "Safe Links is enabled for teams messages."
        }
    }
}
