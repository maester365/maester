Describe "CISA SCuBA" -Tag "MS.EXO", "MS.EXO.9.5", "CISA", "Security", "All" {
    It "MS.EXO.9.5: At a minimum, click-to-run files SHOULD be blocked (e.g., .exe, .cmd, and .vbe)." {

        $result = Test-MtCisaBlockExecutable

        if ($null -ne $result) {
            $result | Should -Be $true -Because "preset policies are enabled."
        }
    }
}