Describe 'Maester/Exchange' -Tag 'Maester', 'Exchange' {





    It 'MT.1062: Ensure Direct Send is set to be rejected' -Tag 'MT.1062' {

        $result = Test-MtExoRejectDirectSend

        if ($result -ne $true) {
            $result | Should -Be $true -Because 'RejectDirectSend should be True.'
        }
    }


    It 'MT.1076: MOERA SHOULD NOT be used for sent mail' -Tag 'MT.1076' {

        $result = Test-MtExoMoeraMailActivity

        if ($result -ne $true) {
            $result | Should -Be $true -Because 'MOERA is not in use.'
        }
    }

    It 'MT.1083: Ensure Delicensing Resiliency is enabled' -Tag 'MT.1083' {

        $result = Test-MtExoDelicensingResiliency

        if ($result -ne $true) {
            $result | Should -Be $true -Because 'Delicensing Resiliency should be enabled.'
        }
    }

    # Ensure 'External sharing' of calendars is not available:
    # > CIS 1.3.3 (L2) Ensure 'External sharing' of calendars is not available
    # > MS.EXO.6.2: Calendar details SHALL NOT be shared with all domains.

    # Ensure the customer lockbox feature is enabled:
    # > CIS 1.3.6 (L2) Ensure the customer lockbox feature is enabled

    # Ensure mailbox auditing for all users is Enabled:
    # > MS.EXO.13.1: Mailbox auditing SHALL be enabled.
}
