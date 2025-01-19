# Generated on 01/18/2025 19:18:58 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA224", "EXO", "Security", "All" {
    It "ORCA224: Similar Users Safety Tips" {
        $result = Get-ORCA224

        if($null -ne $result) {
            $result | Should -Be $true -Because "Similar Users Safety Tips is enabled"
        }
    }
}
