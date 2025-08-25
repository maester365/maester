# Generated on 08/10/2025 15:41:32 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA.237", "EXO", "Security" {
    It "ORCA.237: Safe Links is enabled for teams messages." {
        $result = Test-ORCA237

        if($null -ne $result) {
            $result | Should -Be $true -Because "Safe Links is enabled for teams messages."
        }
    }
}
