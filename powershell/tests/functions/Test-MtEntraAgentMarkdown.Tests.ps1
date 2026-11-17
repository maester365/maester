BeforeDiscovery {
    $checks = @(
        @{ Id = 'MT.1200'; Command = 'Test-MtEntraAgentIdentityOrphaned' }
        @{ Id = 'MT.1201'; Command = 'Test-MtEntraAgentUserOrphaned' }
        @{ Id = 'MT.1203'; Command = 'Test-MtEntraAgentBlueprintOrphaned' }
        @{ Id = 'MT.1204'; Command = 'Test-MtEntraAgentOwner' }
        @{ Id = 'MT.1205'; Command = 'Test-MtEntraAgentSponsor' }
        @{ Id = 'MT.1206'; Command = 'Test-MtEntraAgentInactive' }
        @{ Id = 'MT.1207'; Command = 'Test-MtEntraAgentForeignPrivileged' }
        @{ Id = 'MT.1208'; Command = 'Test-MtEntraAgentBlueprintCredentialHygiene' }
        @{ Id = 'MT.1209'; Command = 'Test-MtEntraAgentDirectoryRoles' }
        @{ Id = 'MT.1210'; Command = 'Test-MtEntraAgentUserExcessiveAccess' }
        @{ Id = 'MT.1211'; Command = 'Test-MtEntraAgentBlueprintAllAllowedInheritance' }
        @{ Id = 'MT.1212'; Command = 'Test-MtEntraAgentBlueprintOpenAccess' }
        @{ Id = 'MT.1213'; Command = 'Test-MtEntraAgentBlueprintRedirectUriHygiene' }
        @{ Id = 'MT.1223'; Command = 'Test-MtEntraAgentHighRiskGraphPermissions' }
    )
    $names = @(
        @{ Shape = 'disguised link'; Text = '[Sign in](https://phish.example/login)'; Escaped = '\[Sign in\]\(https\://phish.example/login\)' }
        @{ Shape = 'image'; Text = '![beacon](https://phish.example/pixel.png)'; Escaped = '\!\[beacon\]\(https\://phish.example/pixel.png\)' }
        @{ Shape = 'formatting'; Text = 'Contoso **admin** _app_ ~test~ \path `code` <owner> & Support'; Escaped = 'Contoso \*\*admin\*\* \_app\_ \~test\~ \\path \`code\` &lt;owner&gt; &amp; Support' }
        @{ Shape = 'bare URL'; Text = 'https://phish.example/login'; Escaped = 'https\://phish.example/login' }
        @{ Shape = 'www URL'; Text = 'www.phish.example/login'; Escaped = 'www\.phish.example/login' }
        @{ Shape = 'email'; Text = 'admin@phish.example'; Escaped = 'admin\@phish.example' }
        @{ Shape = 'table and line breaks'; Text = "Contoso | Admin`r`nSecond row`rThird row`nFourth"; Escaped = 'Contoso \| Admin Second row Third row Fourth' }
        # Keep the existing HTML encoding as well: Markdown decodes a raw &copy; or &#65;.
        @{ Shape = 'literal HTML entities'; Text = 'Contoso &copy; &#65; &#x41; &amp;'; Escaped = 'Contoso &amp;copy; &amp;#65; &amp;#x41; &amp;amp;' }
    )
    $findingCases = foreach ($check in $checks) {
        foreach ($name in $names) { $check + $name }
    }
    $observationCases = foreach ($check in $checks | Where-Object Id -In 'MT.1207', 'MT.1209', 'MT.1210') {
        foreach ($name in $names) { $check + $name }
    }
}

Describe 'Entra Agent ID result Markdown' {
    BeforeAll {
        Import-Module "$PSScriptRoot/../../Maester.psd1" -Force
    }

    BeforeEach {
        $script:AgentMarkdownTest = @{
            Id = ''; Shape = ''; Text = ''; Name = ''; RoleName = 'Global Administrator'
            ObserveOnly = $false; Result = $null; SkippedBecause = $null
        }
        Mock Add-MtTestResultDetail -ModuleName Maester {
            $script:AgentMarkdownTest.Result = $Result
            $script:AgentMarkdownTest.SkippedBecause = $SkippedBecause
        }
        Mock Get-MtDirectoryRoleAssignment -ModuleName Maester {
            @{
                Assignments = @([pscustomobject]@{ principalId = 'user-1'; roleDefinitionId = 'role-1'; directoryScopeId = '/' })
                EligibleChecked = $true
            }
        }
        Mock Get-MtEntraAgentHighRiskGraphPermissionFinding -ModuleName Maester {
            @{
                AgentCount = 1
                Findings = @([pscustomobject]@{
                    AgentId = 'agent-1'; DisplayName = $script:AgentMarkdownTest.Name; AppId = 'agent-app'
                    Permission = 'Policy.ReadWrite.ConditionalAccess'; PermissionType = 'Application'; AttackPath = 'Direct'
                })
            }
        }
        Mock Invoke-MtGraphRequest -ModuleName Maester {
            $test = $script:AgentMarkdownTest
            switch -Wildcard ($RelativeUri) {
                'organization' { return @([pscustomobject]@{ id = 'local-tenant' }) }
                'servicePrincipals/microsoft.graph.agentIdentity' {
                    return @([pscustomobject]@{
                        id = 'agent-1'; appId = 'agent-app'; displayName = $test.Name
                        agentIdentityBlueprintId = 'blueprint-app'; accountEnabled = $true; createdDateTime = '2000-01-01T00:00:00Z'
                    })
                }
                'servicePrincipals/microsoft.graph.agentIdentityBlueprintPrincipal' {
                    if ($test.Id -eq 'MT.1200') { return @() }
                    return @([pscustomobject]@{
                        id = 'principal-1'; appId = 'blueprint-app'; displayName = $test.Name
                        appOwnerOrganizationId = 'foreign-tenant'; appRoleAssignmentRequired = $false
                        appRoles = @([pscustomobject]@{ id = 'app-role'; isEnabled = $true })
                    })
                }
                'applications/microsoft.graph.agentIdentityBlueprint' {
                    if ($test.Id -eq 'MT.1203') { return @() }
                    return @([pscustomobject]@{
                        id = 'blueprint-1'; appId = 'blueprint-app'; displayName = $test.Name
                        passwordCredentials = @([pscustomobject]@{ keyId = 'secret-1'; startDateTime = '2000-01-01T00:00:00Z'; endDateTime = '2001-01-01T00:00:00Z' })
                        keyCredentials = @([pscustomobject]@{ keyId = 'key-1'; startDateTime = '2020-01-01T00:00:00Z'; endDateTime = '2100-01-01T00:00:00Z' })
                        web = @{ redirectUris = @('http://phish.example/*') }
                    })
                }
                'users/microsoft.graph.agentUser' {
                    return @([pscustomobject]@{
                        id = 'user-1'; displayName = $test.Name; userPrincipalName = 'agent_user@phish.example'; identityParentId = 'missing-agent'
                    })
                }
                'roleManagement/directory/roleAssignments' {
                    return @(
                        [pscustomobject]@{ principalId = 'principal-1'; roleDefinitionId = 'role-1'; directoryScopeId = '/' }
                        [pscustomobject]@{ principalId = 'agent-1'; roleDefinitionId = 'role-1'; directoryScopeId = '/' }
                    )
                }
                'roleManagement/directory/roleDefinitions' {
                    return @([pscustomobject]@{ id = 'role-1'; displayName = $test.RoleName })
                }
                '*/transitiveMemberOf/microsoft.graph.group' {
                    if ($test.ObserveOnly) { return @() }
                    return @([pscustomobject]@{ id = 'group-1'; displayName = $test.Name; isAssignableToRole = $true })
                }
                '*/appRoleAssignments' {
                    if ($test.ObserveOnly) { return @() }
                    return @([pscustomobject]@{ id = 'assignment-1'; resourceDisplayName = $test.Name })
                }
                '*/inheritablePermissions' {
                    return @([pscustomobject]@{
                        resourceAppId = 'resource-app'; inheritableScopes = @{ kind = 'allAllowed' }; inheritableRoles = @{ kind = 'allAllowed' }
                    })
                }
                '*/owners' { return @() }
                '*/sponsors' { return @() }
                'reports/*' { return @() }
                default { throw "Unexpected Graph request: $RelativeUri" }
            }
        }
    }

    AfterAll {
        Remove-Variable -Name AgentMarkdownTest -Scope Script -ErrorAction SilentlyContinue
    }

    It '<Id> keeps a <Shape> literal in findings' -ForEach $findingCases {
        $script:AgentMarkdownTest.Id = $Id
        $script:AgentMarkdownTest.Shape = $Shape
        $script:AgentMarkdownTest.Text = $Text
        $script:AgentMarkdownTest.Name = $Text

        $verdict = InModuleScope Maester -Parameters @{ CheckCommand = $Command } {
            param($CheckCommand)
            & $CheckCommand
        }

        $verdict | Should -BeFalse
        $script:AgentMarkdownTest.SkippedBecause | Should -BeNullOrEmpty
        $script:AgentMarkdownTest.Result | Should -Match ([regex]::Escape($Escaped))
        $script:AgentMarkdownTest.Result | Should -Not -Match ([regex]::Escape($Text))
        if ($Id -in 'MT.1201', 'MT.1210') {
            $script:AgentMarkdownTest.Result | Should -Match 'agent\\_user\\@phish\.example'
        }
        if ($Id -eq 'MT.1213') {
            $script:AgentMarkdownTest.Result | Should -Match 'http\\://phish\.example/\\\*'
        }
    }

    It '<Id> keeps a custom role containing a <Shape> literal in passing observations' -ForEach $observationCases {
        $script:AgentMarkdownTest.Id = $Id
        $script:AgentMarkdownTest.Shape = "observation: $Shape"
        $script:AgentMarkdownTest.Text = $Text
        $script:AgentMarkdownTest.Name = 'Ordinary agent'
        $script:AgentMarkdownTest.RoleName = $Text
        $script:AgentMarkdownTest.ObserveOnly = $true

        $verdict = InModuleScope Maester -Parameters @{ CheckCommand = $Command } {
            param($CheckCommand)
            & $CheckCommand
        }

        $verdict | Should -BeTrue
        $script:AgentMarkdownTest.SkippedBecause | Should -BeNullOrEmpty
        $script:AgentMarkdownTest.Result | Should -Match 'Observation:'
        $script:AgentMarkdownTest.Result | Should -Match ([regex]::Escape($Escaped))
        $script:AgentMarkdownTest.Result | Should -Not -Match ([regex]::Escape($Text))
    }
}
