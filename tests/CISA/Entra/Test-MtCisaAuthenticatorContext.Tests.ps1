BeforeDiscovery {
    $EntraIDPlan = Get-MtLicenseInformation -Product EntraID

    $result = Get-MtAuthenticationMethodPolicyConfig

    $authenticator = $result | Where-Object { $_.id -eq "MicrosoftAuthenticator" }
}

Describe "CISA SCuBA" -Tag "MS.AAD", "MS.AAD.3.3", "CISA", "Security", "All" -Skip:( $EntraIDPlan -eq "Free" ) {
    It "MS.AAD.3.3: If phishing-resistant MFA has not been enforced and Microsoft Authenticator is enabled, it SHALL be configured to show login context information." {
        if(-not (Test-MtCisaPhishResistant) -and $authenticator.state -eq "enabled") {
            Test-MtCisaAuthenticatorContext | Should -Be $true -Because "Microsoft Authenticator is configured to show login context information."
        }
    }
}