# Generated on 03/11/2025 11:45:07 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA230", "EXO", "Security", "All" {
    It "ORCA230: Each domain has a Anti-phishing policy applied to it, or the default policy is being used." {
        $result = Test-ORCA230

        if($null -ne $result) {
            $result | Should -Be $true -Because "Each domain has a Anti-phishing policy applied to it, or the default policy is being used."
        }
    }
}
