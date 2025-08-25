# Generated on 08/10/2025 15:41:32 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA.189.2", "EXO", "Security" {
    It "ORCA.189.2: Safe Links is not bypassed." {
        $result = Test-ORCA189_2

        if($null -ne $result) {
            $result | Should -Be $true -Because "Safe Links is not bypassed."
        }
    }
}
