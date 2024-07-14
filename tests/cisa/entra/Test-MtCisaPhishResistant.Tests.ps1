BeforeDiscovery {
    $EntraIDPlan = Get-MtLicenseInformation -Product EntraID
}

Describe "CISA SCuBA" -Tag "MS.AAD", "MS.AAD.3.1", "CISA", "Security", "All" -Skip:( $EntraIDPlan -eq "Free" ) {
    It "MS.AAD.3.1: Phishing-resistant MFA SHALL be enforced for all users." {
        Test-MtCisaPhishResistant | Should -Be $true -Because "an enabled conditional access policy requires phishing-resistant MFA for all apps."
    }
}