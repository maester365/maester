# Generated on 03/04/2025 09:42:24 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA205", "EXO", "Security", "All" {
    It "ORCA205: Common attachment type filter is enabled." {
        $result = Test-ORCA205

        if($null -ne $result) {
            $result | Should -Be $true -Because "Common attachment type filter is enabled."
        }
    }
}
