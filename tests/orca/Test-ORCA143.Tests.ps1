# Generated on 03/04/2025 10:12:41 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA143", "EXO", "Security", "All" {
    It "ORCA143: Safety Tips are enabled." {
        $result = Test-ORCA143

        if($null -ne $result) {
            $result | Should -Be $true -Because "Safety Tips are enabled."
        }
    }
}
