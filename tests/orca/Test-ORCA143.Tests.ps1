# Generated on 04/16/2025 21:38:23 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA.143", "EXO", "Security", "All" {
    It "ORCA.143: Safety Tips are enabled." {
        $result = Test-ORCA143

        if($null -ne $result) {
            $result | Should -Be $true -Because "Safety Tips are enabled."
        }
    }
}
