Describe "CISA SCuBA" -Tag "MS.EXO", "MS.EXO.9.4", "CISA", "Security", "All" {
    It "MS.EXO.9.4: Alternatively chosen filtering solutions SHOULD offer services comparable to Microsoft Defender's Common Attachment Filter." {

        $result = Test-MtCisaEmailFilterAlternative

        if ($null -ne $result) {
            $result | Should -Be $true -Because "should not pass."
        }
    }
}