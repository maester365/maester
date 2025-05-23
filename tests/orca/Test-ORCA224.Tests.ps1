# Generated on 04/16/2025 21:38:23 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA.224", "EXO", "Security", "All" {
    It "ORCA.224: Similar Users Safety Tips is enabled." {
        $result = Test-ORCA224

        if($null -ne $result) {
            $result | Should -Be $true -Because "Similar Users Safety Tips is enabled."
        }
    }
}
