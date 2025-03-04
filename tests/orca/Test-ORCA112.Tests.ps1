# Generated on 03/04/2025 10:12:40 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA112", "EXO", "Security", "All" {
    It "ORCA112: Anti-spoofing protection action is configured to Move message to the recipients' Junk Email folders in Anti-phishing policy." {
        $result = Test-ORCA112

        if($null -ne $result) {
            $result | Should -Be $true -Because "Anti-spoofing protection action is configured to Move message to the recipients' Junk Email folders in Anti-phishing policy."
        }
    }
}
