# Generated on 01/19/2025 05:57:37 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA224", "EXO", "Security", "All" {
    It "ORCA224: Similar Users Safety Tips" {
        $result = Test-ORCA224

        if($null -ne $result) {
            $result | Should -Be $true -Because "Similar Users Safety Tips is enabled"
        }
    }
}
