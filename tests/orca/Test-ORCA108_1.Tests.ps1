# Generated on 03/11/2025 11:45:06 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA108_1", "EXO", "Security", "All" {
    It "ORCA108_1: DNS Records have been set up to support DKIM." {
        $result = Test-ORCA108_1

        if($null -ne $result) {
            $result | Should -Be $true -Because "DNS Records have been set up to support DKIM."
        }
    }
}
