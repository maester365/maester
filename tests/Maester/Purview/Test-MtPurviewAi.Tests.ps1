Describe "Maester/Purview" -Tag "Maester", "Purview" {
    It "MT.1152: Unified audit log ingestion is enabled for AI activity. See https://maester.dev/docs/tests/MT.1152" -Tag "MT.1152" {
        $result = Test-MtPurviewAiAuditLogIngestion
        if ($null -ne $result) {
            $result | Should -Be $true -Because "the unified audit log is enabled so Microsoft 365 Copilot prompts and responses are captured."
        }
    }

    It "MT.1153: Sensitivity labels are published for files used by Microsoft 365 Copilot. See https://maester.dev/docs/tests/MT.1153" -Tag "MT.1153" {
        $result = Test-MtPurviewAiSensitivityLabelsForFiles
        if ($null -ne $result) {
            $result | Should -Be $true -Because "Microsoft 365 Copilot only honors and inherits sensitivity labels when at least one published label is scoped to files."
        }
    }

    It "MT.1154: Insider Risk Management policy for Risky AI usage is enabled. See https://maester.dev/docs/tests/MT.1154" -Tag "MT.1154" {
        $result = Test-MtPurviewAiInsiderRiskPolicy
        if ($null -ne $result) {
            $result | Should -Be $true -Because "risky Microsoft 365 Copilot and AI-app interactions should generate triageable alerts."
        }
    }

    It "MT.1155: DLP policy is configured for the Microsoft 365 Copilot location. See https://maester.dev/docs/tests/MT.1155" -Tag "MT.1155" {
        $result = Test-MtPurviewAiDlpPolicy
        if ($null -ne $result) {
            $result | Should -Be $true -Because "Microsoft 365 Copilot should be blocked from summarising or surfacing files containing sensitive information."
        }
    }

    It "MT.1156: Retention policy is configured for the Microsoft Copilot location. See https://maester.dev/docs/tests/MT.1156" -Tag "MT.1156" {
        $result = Test-MtPurviewAiRetentionPolicy
        if ($null -ne $result) {
            $result | Should -Be $true -Because "Microsoft 365 Copilot prompts and responses should be governed by a defined retention schedule."
        }
    }
}
