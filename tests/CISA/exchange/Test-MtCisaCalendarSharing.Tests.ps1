Describe "CISA SCuBA" -Tag "MS.EXO", "MS.EXO.6.2", "CISA", "Security", "All" {
    It "MS.EXO.6.2: Calendar details SHALL NOT be shared with all domains." {

        $cisaCalendarSharing = Test-MtCisaCalendarSharing

        if($null -ne $cisaCalendarSharing) {
            $cisaCalendarSharing | Should -Be $true -Because "calendar sharing is disabled."
        }
    }
}