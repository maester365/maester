Describe "Maester/Purview" -Tag "Maester", "Purview" {
    It "MT.1172: Unified audit log ingestion is enabled. See https://maester.dev/docs/tests/MT.1172" -Tag "MT.1172" {
        $result = Test-MtPurviewAuditLogIngestion
        if ($null -ne $result) {
            $result | Should -Be $true -Because "the unified audit log is enabled so tenant activity is captured for Microsoft Purview."
        }
    }

    It "MT.1173: Sensitivity labels are published for files used by Microsoft 365 Copilot. See https://maester.dev/docs/tests/MT.1173" -Tag "MT.1173" {
        $result = Test-MtPurviewAiSensitivityLabelsForFiles
        if ($null -ne $result) {
            $result | Should -Be $true -Because "Microsoft 365 Copilot only honors and inherits sensitivity labels when at least one published label is scoped to files."
        }
    }

    It "MT.1174: Insider Risk Management policy for Risky AI usage is enabled. See https://maester.dev/docs/tests/MT.1174" -Tag "MT.1174" {
        $result = Test-MtPurviewAiInsiderRiskPolicy
        if ($null -ne $result) {
            $result | Should -Be $true -Because "risky Microsoft 365 Copilot and AI-app interactions should generate triageable alerts."
        }
    }

    It "MT.1175: DLP policy is configured for the Microsoft 365 Copilot location. See https://maester.dev/docs/tests/MT.1175" -Tag "MT.1175" {
        $result = Test-MtPurviewAiDlpPolicy
        if ($null -ne $result) {
            $result | Should -Be $true -Because "Microsoft 365 Copilot should be blocked from summarising or surfacing files containing sensitive information."
        }
    }

    It "MT.1176: Retention policy is configured for the Microsoft Copilot location. See https://maester.dev/docs/tests/MT.1176" -Tag "MT.1176" {
        $result = Test-MtPurviewAiRetentionPolicy
        if ($null -ne $result) {
            $result | Should -Be $true -Because "Microsoft 365 Copilot prompts and responses should be governed by a defined retention schedule."
        }
    }
}
