# Generated on 03/04/2025 09:34:37 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA189_2", "EXO", "Security", "All" {
    It "ORCA189_2: Safe Links is not bypassed." {
        $result = Test-ORCA189_2

        if($null -ne $result) {
            $result | Should -Be $true -Because "Safe Links is not bypassed."
        }
    }
}
