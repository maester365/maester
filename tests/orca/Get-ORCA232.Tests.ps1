# Generated on 01/18/2025 19:18:58 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA232", "EXO", "Security", "All" {
    It "ORCA232: Malware Filter Policy Policy Rules" {
        $result = Get-ORCA232

        if($null -ne $result) {
            $result | Should -Be $true -Because "Each domain has a malware filter policy applied to it, or the default policy is being used"
        }
    }
}
