BeforeDiscovery {
    try {
        $DefenderPlan = Get-MtLicenseInformation -Product "DefenderXDR"
    } catch {
        $DefenderPlan = "NotConnected"
    }
}

Describe "Exposure Management" -Tag "Entra", "Graph", "Security", "XSPM" -Skip:( $DefenderPlan -ne "DefenderXDR" ) {
    # Privileged assets, identified by EntraOps and Critical Asset Management, should not be exposed due to weak security configurations.
    It "MT.1085: Pending approvals for Critical Asset Management should not be present. See https://maester.dev/docs/tests/MT.1085" -Tag "MT.1085" {
        Test-MtXspmPendingApprovalCriticalAssetManagement | Should -Be $true -Because "no pending approvals for Critical Asset Management should be present, as pending approvals may lead into limited visibility in Defender XDR and potential security risks if critical assets are not properly identified."
    }

    # Devices should not share both critical and non-critical user credentials.
    It "MT.1086: Devices should not share both critical and non-critical user credentials. See https://maester.dev/docs/tests/MT.1086" -Tag "MT.1086" {
        Test-MtXspmCriticalCredsOnDevicesWithNonCriticalAccounts | Should -Be $true -Because "Devices should not share both critical and non-critical user credentials, as this may lead to potential security risks and compromise of critical assets via a non-critical account."
    }

    # Devices should not be public exposed with remotely exploitable, highly likely to be exploited, high or critical severity CVE's.
    It "MT.1087: Devices should not be public exposed with remotely exploitable, highly likely to be exploited, high or critical severity CVE's. See https://maester.dev/docs/tests/MT.1087" -Tag "MT.1087" {
        Test-MtXspmPublicRemotelyExploitableHighExposureDevices | Should -Be $true -Because "Devices should not be public exposed with remotely exploitable, highly likely to be exploited, high or critical severity CVE's. Such devices are at high risk of being compromised by attackers, potentially leading to data breaches and other security incidents."
    }

    # Devices with critical credentials should be protected by TPM.
    It "MT.1088: Devices with critical credentials should be protected by TPM. See https://maester.dev/docs/tests/MT.1088" -Tag "MT.1088" {
        Test-MtXspmCriticalCredentialsOnNonTpmProtectedDevices | Should -Be $true -Because "Devices with critical credentials should be protected by TPM. Without TPM protection, these devices are vulnerable to various attacks that could compromise sensitive credentials, leading to potential security breaches."
    }
}
