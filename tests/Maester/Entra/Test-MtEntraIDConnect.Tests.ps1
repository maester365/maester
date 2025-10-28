BeforeDiscovery {
    try {
        $EntraIDPlan = Get-MtLicenseInformation -Product "EntraID"
    } catch {
        $EntraIDPlan = "NotConnected"
    }
}

Describe "Maester/Entra" -Tag "EntraIdConnect", "Entra", "Graph", "Security" {
    It "MT.1084: Microsoft Entra seamless single sign-on should be disabled for all domains in EntraID Connect servers. See https://maester.dev/docs/tests/MT.1084" -Tag "MT.1084" -Skip:( $EntraIDPlan -ne "P2" ) {
        Test-MtEntraIDConnectSsso | Should -Be $True -Because "Microsoft Entra seamless single sign-on should be disabled for all domains in EntraID Connect servers."
    }
}
