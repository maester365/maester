# Generated on 01/19/2025 07:06:35 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA112", "EXO", "Security", "All" {
    It "ORCA112: Anti-spoofing protection action" {
        $result = Test-ORCA112

        if($null -ne $result) {
            $result | Should -Be $true -Because " Junk Email folders in Anti-phishing policy"
        }
    }
}
