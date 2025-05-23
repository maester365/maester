# Generated on 04/16/2025 21:38:23 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA.112", "EXO", "Security", "All" {
    It "ORCA.112: Anti-spoofing protection action is configured to Move message to the recipients' Junk Email folders in Anti-phishing policy." {
        $result = Test-ORCA112

        if($null -ne $result) {
            $result | Should -Be $true -Because "Anti-spoofing protection action is configured to Move message to the recipients' Junk Email folders in Anti-phishing policy."
        }
    }
}
