# Generated on 01/18/2025 19:18:58 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA230", "EXO", "Security", "All" {
    It "ORCA230: Anti-phishing Rules" {
        $result = Get-ORCA230

        if($null -ne $result) {
            $result | Should -Be $true -Because "Each domain has a Anti-phishing policy applied to it, or the default policy is being used"
        }
    }
}
