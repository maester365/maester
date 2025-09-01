Describe "CISA" -Tag "MS.EXO", "MS.EXO.6.2", "CISA.MS.EXO.6.2", "CISA", "Security" {
    It "CISA.MS.EXO.6.2: Calendar details SHALL NOT be shared with all domains." {

        $cisaCalendarSharing = Test-MtCisaCalendarSharing

        if($null -ne $cisaCalendarSharing) {
            $cisaCalendarSharing | Should -Be $true -Because "calendar sharing is disabled."
        }
    }
}
