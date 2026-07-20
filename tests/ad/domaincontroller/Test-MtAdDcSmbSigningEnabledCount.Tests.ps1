Describe "Active Directory - Domain Controllers" -Tag "AD", "AD.DomainController", "AD-DC-04" {
    It "AD-DC-04: SMB signing should be enabled on all domain controllers" {

        $result = Test-MtAdDcSmbSigningEnabledCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "SMB signing helps prevent man-in-the-middle attacks"
        }
    }
}
