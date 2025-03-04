# Generated on 03/04/2025 09:34:38 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA242", "EXO", "Security", "All" {
    It "ORCA242: Important protection alerts responsible for AIR activities are enabled." {
        $result = Test-ORCA242

        if($null -ne $result) {
            $result | Should -Be $true -Because "Important protection alerts responsible for AIR activities are enabled."
        }
    }
}
