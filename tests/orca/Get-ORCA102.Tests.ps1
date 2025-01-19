# Generated on 01/18/2025 19:18:57 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA102", "EXO", "Security", "All" {
    It "ORCA102: Advanced Spam Filter (ASF)" {
        $result = Get-ORCA102

        if($null -ne $result) {
            $result | Should -Be $true -Because "Advanced Spam filter options are turned off"
        }
    }
}
