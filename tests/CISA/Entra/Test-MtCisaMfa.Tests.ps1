BeforeDiscovery {
    $EntraIDPlan = Get-MtLicenseInformation -Product EntraID
}

Describe "CISA SCuBA" -Tag "MS.AAD", "MS.AAD.3.2", "CISA", "Security", "All" -Skip:( ($EntraIDPlan -eq "Free") -or (Test-MtCisaPhishResistant)) {
    It "MS.AAD.3.2: If phishing-resistant MFA has not been enforced, an alternative MFA method SHALL be enforced for all users." {
        Test-MtCisaMfa | Should -Be $true -Because "an enabled conditional access policy requires MFA for all apps."
    }
}