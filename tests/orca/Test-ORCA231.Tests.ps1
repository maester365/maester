# Generated on 08/10/2025 15:41:32 by .\build\orca\Update-OrcaTests.ps1

Describe "ORCA" -Tag "ORCA", "ORCA.231", "EXO", "Security" {
    It "ORCA.231: Each domain has a anti-spam policy applied to it, or the default policy is being used." {
        $result = Test-ORCA231

        if($null -ne $result) {
            $result | Should -Be $true -Because "Each domain has a anti-spam policy applied to it, or the default policy is being used."
        }
    }
}
