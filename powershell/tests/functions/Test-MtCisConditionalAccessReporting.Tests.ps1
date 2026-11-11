BeforeDiscovery {
    $cases = foreach ($id in @('1.3.2') + @(1..13 + 15..17 | ForEach-Object { "5.2.2.$_" })) {
        foreach ($state in @('enabled','disabled','enabledForReportingButNotEnforced')) {
            @{ Id = "CIS.M365.$id"; State = $state; Expected = $state -eq 'enabled' }
        }
    }
}
BeforeAll {
    $script:root = (Resolve-Path "$PSScriptRoot/../../..").Path
    Import-Module "$script:root/powershell/Maester.psd1" -Force
    $script:adminRoles = @(& (Get-Module Maester) { Get-MtCisAdministratorRole | ForEach-Object Id })
}
Describe 'CIS Conditional Access tables with tenant-controlled names' {
    BeforeEach {
        $script:plan = Get-Content "$script:root/powershell/tests/fixtures/conditional-access-plans/plan.json" -Raw | ConvertFrom-Json -AsHashtable
        $script:rule = (Get-Content "$script:root/powershell/tests/fixtures/conditional-access-plans/rules.json" -Raw | ConvertFrom-Json -AsHashtable).value[0]
        $script:plan.displayName = "CA | [Prod] \ Main`nPlan"
        $script:rule.displayName = 'MFA | **required** [review](https://example.invalid)'
        $script:rule.conditions = $null
        $script:standalonePolicy = $null
        $script:rule.controls.grantControls = @{ operator='OR'; builtInControls=@('mfa'); customAuthenticationFactors=@(); termsOfUse=@(); authenticationStrength=$null }
        $script:rule.controls.sessionControls = $null
        $script:plan.sharedConditions.users = @{ includeUsers=@('All'); excludeUsers=@(); includeGroups=@();excludeGroups=@();includeRoles=$script:adminRoles;excludeRoles=@() }
        $script:plan.sharedConditions.applications = @{ includeApplications=@('All');excludeApplications=@();includeUserActions=@();includeAuthenticationContextClassReferences=@();applicationFilter=$null }
        Mock Test-MtConnection -ModuleName Maester { $true }
        Mock Get-MgContext -ModuleName Maester { $null }
        Mock Invoke-MtGraphRequest -ModuleName Maester {
            switch -Wildcard ($RelativeUri) {
                'organization' { [pscustomobject]@{ DisplayName = 'Report test tenant' } }
                'identity/conditionalAccess/policies' { $script:standalonePolicy }
                'identity/conditionalAccess/plans' { [pscustomobject]$script:plan }
                'identity/conditionalAccess/plans/*/rules' { [pscustomobject]$script:rule }
                'identity/conditionalAccess/namedLocations' { @() }
                'policies/activityBasedTimeoutPolicies' { [pscustomobject]@{ definition=@('{"ActivityBasedTimeoutPolicy":{"ApplicationPolicies":[{"WebSessionIdleTimeout":"03:00:00"}]}}') } }
                default { throw "Unexpected endpoint: $RelativeUri" }
            }
        }
    }
    It '<Id> preserves table columns and the <State> verdict for policies and plan rules' -ForEach $cases {
        $script:rule.state = $State
        $scope = $script:plan.sharedConditions
        $controls = $script:rule.controls
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
        $script:standalonePolicy = [pscustomobject]@{
            id = 'standalone-policy'
            displayName = 'Standalone | [Prod] \ Access'
            state = $State
            conditions = $scope
            grantControls = $controls.grantControls
            sessionControls = $controls.sessionControls
        }
        $config = [pscustomobject]@{
            Environment = [pscustomobject]@{
                Licenses = @('AAD_PREMIUM', 'AAD_PREMIUM_P2')
                Services = [pscustomobject]@{ Graph = $true }
            }
        }
        $row = Invoke-MtTest -Id $Id -Config $config
        $outcome = if ($Expected) { 'Passed' } else { 'Failed' }
        $row.Result | Should -Be $outcome -Because ($row.ReasonDetail | Out-String)
        $lines = @($row.ResultDetail.TestResult -split "`n" | Where-Object { $_.StartsWith('|') })
        $columnCount = ([regex]::Split($lines[0], '(?<!\\)\|')).Count
        foreach ($line in $lines) {
            ([regex]::Split($line, '(?<!\\)\|')).Count | Should -Be $columnCount -Because "each result row must keep the header's columns"
        }
        $candidates = @($lines | Where-Object { $_ -like '*Standalone*' -or $_ -like '*Main Plan*' })
        $candidates | Should -HaveCount 2
        foreach ($candidate in $candidates) {
            $cells = [regex]::Split($candidate, '(?<!\\)\|')
            $cells[-2].Trim() | Should -Be $(if ($Expected) { '✅ Pass' } else { '❌ Fail' })
            $candidate | Should -Match ([regex]::Escape($State))
            $candidate | Should -Match '\\\|'
        }
        # The raw inventory is still usable as data, rather than carrying Markdown escapes.
        $script:standalonePolicy.displayName | Should -BeExactly 'Standalone | [Prod] \ Access'
        $script:plan.displayName | Should -BeExactly "CA | [Prod] \ Main`nPlan"
        $report = & (Get-Module Maester) {
            param($row)
            ConvertTo-MtMaesterResult -NativeRows @($row) -SkipVersionCheck
        } $row
        $html = Get-MtHtmlReport -MaesterResults $report
        $match = [regex]::Match($html, '<script type="application/octet-stream" id="maester-report-data" data-encoding="gzip\+base64">([A-Za-z0-9+/=]*)</script>')
        $match.Success | Should -BeTrue
        $stream = [IO.MemoryStream]::new([Convert]::FromBase64String($match.Groups[1].Value))
        $reader = [IO.StreamReader]::new([IO.Compression.GZipStream]::new($stream, [IO.Compression.CompressionMode]::Decompress))
        try { $embedded = $reader.ReadToEnd() | ConvertFrom-Json } finally { $reader.Dispose() }
        $embedded.Tests[0].Result | Should -Be $outcome
        $embedded.Tests[0].ResultDetail.TestResult | Should -BeExactly $row.ResultDetail.TestResult
        $embedded.PassedCount | Should -Be ([int]$Expected)
        $embedded.FailedCount | Should -Be ([int](-not $Expected))
        Should -Invoke Invoke-MtGraphRequest -ModuleName Maester -Times 1 -Exactly -ParameterFilter { $RelativeUri -eq 'identity/conditionalAccess/plans' }
        Should -Invoke Invoke-MtGraphRequest -ModuleName Maester -Times 1 -Exactly -ParameterFilter { $RelativeUri -like 'identity/conditionalAccess/plans/*/rules' }
    }
}
