BeforeDiscovery {
    $cases = foreach ($id in @('1.3.2') + @(1..13 + 15..17 | ForEach-Object { "5.2.2.$_" })) {
        foreach ($state in @('enabled', 'disabled', 'enabledForReportingButNotEnforced')) {
            @{ Id = "CIS.M365.$id"; State = $state; Expected = $state -eq 'enabled' }
        }
    }
}
BeforeAll {
    $script:root = (Resolve-Path "$PSScriptRoot/../../..").Path
    Import-Module "$script:root/powershell/Maester.psd1" -Force
    $script:adminRoles = @(& (Get-Module Maester) { Get-MtCisAdministratorRole | ForEach-Object Id })
}
Describe 'Literal tenant names in CIS Conditional Access results' {
    BeforeEach {
        $script:policy = $null
        Mock Get-MtConditionalAccessPolicy -ModuleName Maester { $script:policy }
        Mock Test-MtConnection -ModuleName Maester { $true }
        Mock Get-MgContext -ModuleName Maester { $null }
        Mock Invoke-MtGraphRequest -ModuleName Maester {
            switch ($RelativeUri) {
                'identity/conditionalAccess/namedLocations' { @() }
                'organization' { [pscustomobject]@{ displayName = 'Report test tenant' } }
                'policies/activityBasedTimeoutPolicies' { [pscustomobject]@{ definition=@('{"ActivityBasedTimeoutPolicy":{"ApplicationPolicies":[{"WebSessionIdleTimeout":"03:00:00"}]}}') } }
                default { throw "Unexpected endpoint: $RelativeUri" }
            }
        }
    }
    It '<Id> preserves replacement tokens and the <State> verdict' -ForEach $cases {
        $name = 'Policy $& $$ $1 ${name}'
        $scope = @{
            users = @{ includeUsers=@('All'); excludeUsers=@(); includeGroups=@(); excludeGroups=@(); includeRoles=$script:adminRoles; excludeRoles=@() }
            applications = @{ includeApplications=@('All'); excludeApplications=@(); includeUserActions=@(); includeAuthenticationContextClassReferences=@(); applicationFilter=$null }
            clientAppTypes = @('all')
            userRiskLevels = @()
            signInRiskLevels = @()
        }
        $controls = @{ grantControls=@{ operator='OR'; builtInControls=@('mfa'); customAuthenticationFactors=@(); termsOfUse=@(); authenticationStrength=$null }; sessionControls=$null }
        switch ($Id) {
            'CIS.M365.1.3.2' {
                $scope.applications.includeApplications=@('Office365');$scope.clientAppTypes=@('browser')
                $controls.sessionControls=@{applicationEnforcedRestrictions=@{isEnabled=$true}}
            }
            'CIS.M365.5.2.2.3' { $scope.clientAppTypes=@('exchangeActiveSync','other');$controls.grantControls.builtInControls=@('block') }
            'CIS.M365.5.2.2.4' { $controls.sessionControls=@{persistentBrowser=@{isEnabled=$true;mode='never'};signInFrequency=@{isEnabled=$true;frequencyInterval='everyTime'}} }
            'CIS.M365.5.2.2.5' { $controls.grantControls.builtInControls=@();$controls.grantControls.authenticationStrength=@{id='strength';allowedCombinations=@('fido2')} }
            'CIS.M365.5.2.2.6' {
                $scope.userRiskLevels=@('high');$controls.grantControls.operator='AND';$controls.grantControls.builtInControls=@('mfa','passwordChange')
                $controls.sessionControls=@{signInFrequency=@{isEnabled=$true;frequencyInterval='everyTime'}}
            }
            'CIS.M365.5.2.2.7' { $scope.signInRiskLevels=@('medium','high');$controls.grantControls.builtInControls=@('block') }
            'CIS.M365.5.2.2.8' { $scope.signInRiskLevels=@('medium','high');$controls.grantControls.builtInControls=@('block') }
            'CIS.M365.5.2.2.9' { $controls.grantControls.builtInControls=@('compliantDevice') }
            'CIS.M365.5.2.2.10' {
                $scope.applications.includeApplications=@();$scope.applications.includeUserActions=@('urn:user:registersecurityinfo')
                $controls.grantControls.builtInControls=@('compliantDevice')
            }
            'CIS.M365.5.2.2.11' {
                $scope.applications.includeApplications=@('d4ebce55-015a-49b5-a083-c84d1797ae8c')
                $controls.sessionControls=@{signInFrequency=@{isEnabled=$true;frequencyInterval='everyTime'}}
            }
            'CIS.M365.5.2.2.12' { $scope.authenticationFlows=@{transferMethods=@('deviceCodeFlow')};$controls.grantControls.builtInControls=@('block') }
            'CIS.M365.5.2.2.13' { $controls.sessionControls=@{signInFrequency=@{isEnabled=$true;frequencyInterval='everyTime'}} }
            'CIS.M365.5.2.2.15' { $scope.locations=@{includeLocations=@('All');excludeLocations=@('AllTrusted')};$controls.grantControls.builtInControls=@('block') }
            'CIS.M365.5.2.2.16' {
                $scope.applications.includeApplications=@('00000002-0000-0ff1-ce00-000000000000','00000003-0000-0ff1-ce00-000000000000','cc15fd57-2c6c-4117-a88c-83b1d56b4bbe')
                $scope.platforms=@{includePlatforms=@('windows');excludePlatforms=@()};$scope.clientAppTypes=@('mobileAppsAndDesktopClients')
                $controls.sessionControls=@{secureSignInSession=@{isEnabled=$true}}
            }
            'CIS.M365.5.2.2.17' { $scope.authenticationFlows=@{transferMethods=@('authenticationTransfer')};$controls.grantControls.builtInControls=@('block') }
        }
        $script:policy = [pscustomobject]@{
            id = 'standalone-policy'
            displayName = $name
            state = $State
            conditions = $scope
            grantControls = $controls.grantControls
            sessionControls = $controls.sessionControls
        }
        $config = [pscustomobject]@{ Environment = [pscustomobject]@{ Licenses=@('AAD_PREMIUM','AAD_PREMIUM_P2'); Services=[pscustomobject]@{Graph=$true} } }
        $row = Invoke-MtTest -Id $Id -Config $config
        $row.Result | Should -Be $(if ($Expected) { 'Passed' } else { 'Failed' }) -Because ($row.ReasonDetail | Out-String)
        $candidate = @($row.ResultDetail.TestResult -split "`n" | Where-Object { $_.StartsWith('| Policy') -and $_.Contains('$&') })
        $candidate | Should -HaveCount 1
        $candidate[0] | Should -Match ([regex]::Escape($name))
        $candidate[0] | Should -Match ([regex]::Escape($State))
        $cells = $candidate[0].Split('|')
        $cells[-2].Trim() | Should -Be $(if ($Expected) { '✅ Pass' } else { '❌ Fail' })
        $script:policy.displayName | Should -BeExactly $name
    }
}
