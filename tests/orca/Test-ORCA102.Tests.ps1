# Generated on 01/18/2025 20:19:55 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA102", "EXO", "Security", "All" {
    It "ORCA102: Advanced Spam Filter (ASF)" {
        $result = Test-ORCA102

        if($null -ne $result) {
            $result | Should -Be $true -Because "Advanced Spam filter options are turned off"
        }
    }
}
