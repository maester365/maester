# Generated on 03/04/2025 09:34:38 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA232", "EXO", "Security", "All" {
    It "ORCA232: Each domain has a malware filter policy applied to it, or the default policy is being used." {
        $result = Test-ORCA232

        if($null -ne $result) {
            $result | Should -Be $true -Because "Each domain has a malware filter policy applied to it, or the default policy is being used."
        }
    }
}
