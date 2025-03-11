# Generated on 03/11/2025 11:45:06 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA205", "EXO", "Security", "All" {
    It "ORCA205: Common attachment type filter is enabled." {
        $result = Test-ORCA205

        if($null -ne $result) {
            $result | Should -Be $true -Because "Common attachment type filter is enabled."
        }
    }
}
