# Generated on 04/16/2025 21:38:23 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA.230", "EXO", "Security", "All" {
    It "ORCA.230: Each domain has a Anti-phishing policy applied to it, or the default policy is being used." {
        $result = Test-ORCA230

        if($null -ne $result) {
            $result | Should -Be $true -Because "Each domain has a Anti-phishing policy applied to it, or the default policy is being used."
        }
    }
}
