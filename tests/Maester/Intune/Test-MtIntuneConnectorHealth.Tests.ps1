Describe "Maester/Intune" -Tag "Maester", "Intune" {
    It "MT.1092: Intune APNS certificate should be valid for more than 30 days" -Tag "MT.1092" {
        $result = Test-MtApplePushNotificationCertificate
        if ($null -ne $result) {
            $result | Should -Be $true -Because "Intune APNS certificate is valid for more than 30 days."
        }
    }
    It "MT.1093: Apple Automated Device Enrollment Tokens should be valid for more than 30 days" -Tag "MT.1093" {
        $result = Test-MtAppleAutomatedDeviceEnrollmentToken
        if ($null -ne $result) {
            $result | Should -Be $true -Because "Intune Automated Device Enrollment token is valid for more than 30 days."
        }
    }
    It "MT.1094: Apple Volume Purchase Program Tokens should be valid for more than 30 days" -Tag "MT.1094" {
        $result = Test-MtAppleVolumePurchaseProgramToken
        if ($null -ne $result) {
            $result | Should -Be $true -Because "Intune Volume Purchase Program token is valid for more than 30 days."
        }
    }

    It "MT.1095: Android Enterprise account connection should be healthy" -Tag "MT.1095" {
        $result = Test-MtAndroidEnterpriseConnection
        if ($null -ne $result) {
            $result | Should -Be $true -Because "Android Enterprise account connection is healthy."
        }
    }

    It "MT.1097: Ensure all Intune Certificate Connectors are healthy and running supported versions" -Tag "MT.1097" {
        $result = Test-MtCertificateConnectors
        if ($null -ne $result) {
            $result | Should -Be $true -Because "all Intune Certificate Connectors are healthy and running supported versions."
        }
    }

    It "MT.1098: Mobile Threat Defense Connectors should be healthy" -Tag "MT.1098" {
        $result = Test-MtMobileThreatDefenseConnectors
        if ($null -ne $result) {
            $result | Should -Be $true -Because "Mobile Threat Defense Connectors are healthy."
        }

    }
}
