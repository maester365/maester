BeforeDiscovery {
    $DataverseUrl = Get-MtMaesterConfigGlobalSetting -SettingName 'DataverseEnvironmentUrl'
    $DataverseConfigured = -not [string]::IsNullOrEmpty($DataverseUrl)
    if (-not $DataverseConfigured) {
        Write-Verbose "DataverseEnvironmentUrl not configured in maester-config.json. AI Agent security tests will be skipped."
    }
}

Describe "AI Agent Security" -Tag "XSPM", "AIAgent" -Skip:( -not $DataverseConfigured ) {
    # AI agents should not be shared with broad access control policies.
    It "MT.1113: AI agents should not be shared with broad access control policies. See https://maester.dev/docs/tests/MT.1113" -Tag "MT.1113" {
        Test-MtAIAgentBroadSharing | Should -Be $true -Because "AI agents with 'Any' or 'Any multitenant' access control allow unauthenticated or cross-tenant access, increasing the risk of unauthorized data access and prompt injection."
    }

    # AI agents should require user authentication.
    It "MT.1114: AI agents should require user authentication. See https://maester.dev/docs/tests/MT.1114" -Tag "MT.1114" {
        Test-MtAIAgentNoAuthentication | Should -Be $true -Because "AI agents without authentication allow anonymous access, making them vulnerable to abuse, data exfiltration, and prompt injection attacks."
    }

    # AI agents should not have risky HTTP configurations.
    It "MT.1115: AI agents should not have risky HTTP configurations. See https://maester.dev/docs/tests/MT.1115" -Tag "MT.1115" {
        Test-MtAIAgentRiskyHttpConfig | Should -Be $true -Because "HTTP actions to non-standard ports or plain HTTP endpoints may indicate data exfiltration or misconfigured integrations."
    }

    # AI agents should not send email with AI-controlled inputs.
    It "MT.1116: AI agents should not send email with AI-controlled inputs. See https://maester.dev/docs/tests/MT.1116" -Tag "MT.1116" {
        Test-MtAIAgentEmailExfiltration | Should -Be $true -Because "Email-sending tools with AI-controlled inputs present a risk of data exfiltration to attacker-controlled addresses."
    }

    # Published AI agents should not be dormant.
    It "MT.1117: Published AI agents should not be dormant. See https://maester.dev/docs/tests/MT.1117" -Tag "MT.1117" {
        Test-MtAIAgentDormant | Should -Be $true -Because "Dormant published agents may have outdated configurations and continue to expose functionality without active maintenance."
    }

    # AI agents should not use author (maker) authentication for connections.
    It "MT.1118: AI agents should not use author (maker) authentication for connections. See https://maester.dev/docs/tests/MT.1118" -Tag "MT.1118" {
        Test-MtAIAgentAuthorAuthentication | Should -Be $true -Because "Agents using author (maker) authentication access external services with the maker's credentials, creating privilege escalation and separation of duties risks."
    }

    # AI agents should not have hard-coded credentials in topics.
    It "MT.1119: AI agents should not have hard-coded credentials in topics. See https://maester.dev/docs/tests/MT.1119" -Tag "MT.1119" {
        Test-MtAIAgentHardCodedCredentials | Should -Be $true -Because "Hard-coded credentials in agent topics can be extracted by prompt injection attacks and persist after key rotation."
    }

    # AI agents should not use MCP server tools without review.
    It "MT.1120: AI agents should not use MCP server tools without review. See https://maester.dev/docs/tests/MT.1120" -Tag "MT.1120" {
        Test-MtAIAgentMcpTools | Should -Be $true -Because "MCP tool integrations extend agents with arbitrary external capabilities and may introduce supply chain risks."
    }

    # AI agents with generative orchestration should have custom instructions.
    It "MT.1121: AI agents with generative orchestration should have custom instructions. See https://maester.dev/docs/tests/MT.1121" -Tag "MT.1121" {
        Test-MtAIAgentMissingInstructions | Should -Be $true -Because "Agents using generative orchestration without custom instructions rely on default LLM behavior, increasing prompt injection and off-topic response risk."
    }

    # AI agents should not have orphaned ownership.
    It "MT.1122: AI agents should not have orphaned ownership. See https://maester.dev/docs/tests/MT.1122" -Tag "MT.1122" {
        Test-MtAIAgentOrphaned | Should -Be $true -Because "Agents whose owners are all disabled or deleted cannot be maintained and may continue operating with outdated or insecure configurations."
    }
}
