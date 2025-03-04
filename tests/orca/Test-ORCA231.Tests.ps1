# Generated on 03/04/2025 09:34:38 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA231", "EXO", "Security", "All" {
    It "ORCA231: Each domain has a anti-spam policy applied to it, or the default policy is being used." {
        $result = Test-ORCA231

        if($null -ne $result) {
            $result | Should -Be $true -Because "Each domain has a anti-spam policy applied to it, or the default policy is being used."
        }
    }
}
