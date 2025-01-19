# Generated on 01/18/2025 20:19:55 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA113", "EXO", "Security", "All" {
    It "ORCA113: Do not let users click through safe links" {
        $result = Test-ORCA113

        if($null -ne $result) {
            $result | Should -Be $true -Because "AllowClickThrough is disabled in Safe Links policies"
        }
    }
}
