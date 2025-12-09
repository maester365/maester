# Generated on 08/10/2025 15:41:31 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA.119", "EXO", "Security" {
    It "ORCA.119: Similar Domains Safety Tips is enabled." {
        $result = Test-ORCA119

        if($null -ne $result) {
            $result | Should -Be $true -Because "Similar Domains Safety Tips is enabled."
        }
    }
}
