BeforeDiscovery {
    $EntraIDPlan = Get-MtLicenseInformation -Product EntraID
}

Describe "CISA SCuBA" -Tag "MS.AAD", "MS.AAD.3.6", "CISA", "Security", "All" -Skip:( $EntraIDPlan -eq "Free" ) {
    It "MS.AAD.3.6: Phishing-resistant MFA SHALL be required for highly privileged roles." {
        Test-MtCisaPrivilegedPhishResistant | Should -Be $true -Because "an enabled conditional access policy for highly privileged roles should require phishing resistant MFA."
    }
}