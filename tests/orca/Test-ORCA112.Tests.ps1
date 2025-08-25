# Generated on 08/10/2025 15:41:31 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA.112", "EXO", "Security" {
    It "ORCA.112: Anti-spoofing protection action is configured to Move message to the recipients' Junk Email folders in Anti-phishing policy." {
        $result = Test-ORCA112

        if($null -ne $result) {
            $result | Should -Be $true -Because "Anti-spoofing protection action is configured to Move message to the recipients' Junk Email folders in Anti-phishing policy."
        }
    }
}
