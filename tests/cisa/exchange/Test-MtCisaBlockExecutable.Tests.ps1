Describe "CISA" -Tag "MS.EXO", "MS.EXO.9.5", "CISA.MS.EXO.9.5", "CISA", "Security" {
    It "CISA.MS.EXO.9.5: At a minimum, click-to-run files SHOULD be blocked (e.g., .exe, .cmd, and .vbe)." {

        $result = Test-MtCisaBlockExecutable

        if ($null -ne $result) {
            $result | Should -Be $true -Because "preset policies are enabled."
        }
    }
}
