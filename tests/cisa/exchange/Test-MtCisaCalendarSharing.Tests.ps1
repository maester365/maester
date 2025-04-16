Describe "CISA SCuBA" -Tag "MS.EXO", "MS.EXO.6.2", "CISA.MS.EXO.06.2", "CISA", "Security", "All" {
    It "CISA.MS.EXO.06.2: Calendar details SHALL NOT be shared with all domains." {

        $cisaCalendarSharing = Test-MtCisaCalendarSharing

        if($null -ne $cisaCalendarSharing) {
            $cisaCalendarSharing | Should -Be $true -Because "calendar sharing is disabled."
        }
    }
}