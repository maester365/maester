# Generated on 01/18/2025 20:19:55 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA119", "EXO", "Security", "All" {
    It "ORCA119: Similar Domains Safety Tips" {
        $result = Test-ORCA119

        if($null -ne $result) {
            $result | Should -Be $true -Because "Similar Domains Safety Tips is enabled"
        }
    }
}
