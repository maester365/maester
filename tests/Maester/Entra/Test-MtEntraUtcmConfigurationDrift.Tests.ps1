﻿Describe "Maester" -Tag "Maester", "Entra", "Preview" {
    It "MT.1172: No active configuration drifts are reported by Microsoft Entra Unified Tenant Configuration Management (UTCM). See https://maester.dev/docs/tests/MT.1172" -Tag "MT.1172", "Preview" {
        $result = Test-MtEntraUtcmConfigurationDrift

        if ($null -ne $result) {
            $result | Should -Be $true -Because "all managed configurations should match their expected baseline values with no active drifts"
        }
    }
}
