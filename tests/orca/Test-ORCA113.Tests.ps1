# Generated on 03/04/2025 09:42:23 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA113", "EXO", "Security", "All" {
    It "ORCA113: AllowClickThrough is disabled in Safe Links policies." {
        $result = Test-ORCA113

        if($null -ne $result) {
            $result | Should -Be $true -Because "AllowClickThrough is disabled in Safe Links policies."
        }
    }
}
