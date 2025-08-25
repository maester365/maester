# Generated on 08/10/2025 15:41:31 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA.108.1", "EXO", "Security" {
    It "ORCA.108.1: DNS Records have been set up to support DKIM." {
        $result = Test-ORCA108_1

        if($null -ne $result) {
            $result | Should -Be $true -Because "DNS Records have been set up to support DKIM."
        }
    }
}
