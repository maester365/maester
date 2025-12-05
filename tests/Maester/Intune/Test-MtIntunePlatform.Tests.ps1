Describe "Maester/Intune" -Tag "Maester", "Intune" {
    It "MT.1053: Ensure intune device clean-up rule is configured" -Tag "MT.1053" {
        $result = Test-MtManagedDeviceCleanupSettings
        if ($null -ne $result) {
            $result | Should -Be $true -Because "automatic device clean-up rule is configured."
        }
    }

    It "MT.1054: Ensure built-in Device Compliance Policy marks devices with no compliance policy assigned as 'Not compliant'" -Tag "MT.1054" {
        $result = Test-MtDeviceComplianceSettings
        if ($null -ne $result) {
            $result | Should -Be $true -Because "built-in device compliance policy marks devices with no policy assigned as 'Not compliant'."
        }
    }

    It "MT.1096: Ensure at least one Intune Multi Admin Approval policy is configured" -Tag "MT.1096" {
        $result = Test-MtOperationApprovalPolicies
        if ($null -ne $result) {
            $result | Should -Be $true -Because "at least one Intune Multi Admin Approval policy is configured."
        }
    }

    It "MT.1099: Windows Diagnostic Data Processing should be enabled" -Tag "MT.1099" {
        $result = Test-MtWindowsDataProcessor
        if ($null -ne $result) {
            $result | Should -Be $true -Because "Windows Diagnostic Data Processing is enabled."
        }
    }

    It "MT.1100: Intune Diagnostic Settings should include Audit Logs" -Tag "MT.1100" {
        $result = Test-MtIntuneDiagnosticSettings
        if ($null -ne $result) {
            $result | Should -Be $true -Because "Intune Diagnostic Settings include Audit Logs."
        }
    }

    It "MT.1101: Default Branding Profile should be customized" -Tag "MT.1101" {
        $result = Test-MtTenantCustomization
        if ($null -ne $result) {
            $result | Should -Be $true -Because "Default Branding Profile is customized."
        }
    }

    It "MT.1102: Windows Feature Update Policy Settings should not reference end of support builds" -Tag "MT.1102" {
        $result = Test-MtFeatureUpdatePolicy
        if ($null -ne $result) {
            $result | Should -Be $true -Because "Windows Feature Update Policy Settings do not reference end of support builds."
        }
    }

    It "MT.1103: Ensure Intune RBAC groups are protected by Restricted Management Administrative Units or Role Assignable groups" -Tag "MT.1103" {
        $result = Test-MtIntuneRbacGroupsProtected
        if ($null -ne $result) {
            $result | Should -Be $true -Because "Intune RBAC groups are protected by Restricted Management Administrative Units or Role Assignable groups."
        }
    }

    It "MT.1105: Ensure MDM Authority is set to Intune" -Tag "MT.1105" {
        $result = Test-MtMdmAuthority
        if ($null -ne $result) {
            $result | Should -Be $true -Because "MDM Authority is set to Intune."
        }
    }
}
