Describe "Active Directory - Trusts" -Tag "AD", "AD.Trust", "AD-TRUST-04" {
    It "AD-TRUST-04: No trusts should lack SID filtering (quarantine)" {

        $result = Test-MtAdTrustNonQuarantinedDetails

        if ($null -ne $result) {
            $result | Should -Be $true -Because "non-quarantined trusts are vulnerable to SID history attacks"
        } else {
            Set-ItResult -Skipped -Because "Active Directory data could not be retrieved"
        }
    }
}
