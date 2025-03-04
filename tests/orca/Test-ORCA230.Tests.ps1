# Generated on 03/04/2025 10:12:41 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA230", "EXO", "Security", "All" {
    It "ORCA230: Each domain has a Anti-phishing policy applied to it, or the default policy is being used." {
        $result = Test-ORCA230

        if($null -ne $result) {
            $result | Should -Be $true -Because "Each domain has a Anti-phishing policy applied to it, or the default policy is being used."
        }
    }
}
