# Generated on 03/04/2025 09:42:23 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA119", "EXO", "Security", "All" {
    It "ORCA119: Similar Domains Safety Tips is enabled." {
        $result = Test-ORCA119

        if($null -ne $result) {
            $result | Should -Be $true -Because "Similar Domains Safety Tips is enabled."
        }
    }
}
