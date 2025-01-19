# Generated on 01/18/2025 19:34:47 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA113", "EXO", "Security", "All" {
    It "ORCA113: Do not let users click through safe links" {
        $result = Test-ORCA113

        if($null -ne $result) {
            $result | Should -Be $true -Because "AllowClickThrough is disabled in Safe Links policies"
        }
    }
}
