# Generated on 04/16/2025 21:38:23 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA.113", "EXO", "Security", "All" {
    It "ORCA.113: AllowClickThrough is disabled in Safe Links policies." {
        $result = Test-ORCA113

        if($null -ne $result) {
            $result | Should -Be $true -Because "AllowClickThrough is disabled in Safe Links policies."
        }
    }
}
