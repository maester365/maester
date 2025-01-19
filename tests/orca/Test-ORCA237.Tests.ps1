# Generated on 01/18/2025 20:19:56 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA237", "EXO", "Security", "All" {
    It "ORCA237: Safe Links protections for links in teams messages" {
        $result = Test-ORCA237

        if($null -ne $result) {
            $result | Should -Be $true -Because "Safe Links is enabled for teams messages"
        }
    }
}
