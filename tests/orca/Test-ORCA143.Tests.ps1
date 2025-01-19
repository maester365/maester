# Generated on 01/18/2025 20:19:56 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA143", "EXO", "Security", "All" {
    It "ORCA143: Safety Tips" {
        $result = Test-ORCA143

        if($null -ne $result) {
            $result | Should -Be $true -Because "Safety Tips are enabled"
        }
    }
}
