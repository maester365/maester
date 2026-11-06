BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force
}

Describe 'MT.1254 Tenant Configuration Management drift' {
    BeforeEach {
        InModuleScope Maester {
            $script:now = (Get-Date).ToUniversalTime()
            $script:monitor = [pscustomobject]@{
                id = 'mon-1'; displayName = 'Security baseline'; status = 'active'; inactivationReason = $null
                monitorRunFrequencyInHours = 6; mode = 'monitorOnly'; createdDateTime = $script:now.AddDays(-30).ToString('o')
            }
            $script:instance = [pscustomobject]@{ Id = 'mon-1'; Data = $script:monitor }
            $script:drifts = @()
            $script:runs = @([pscustomobject]@{
                    monitorId = 'mon-1'; runStatus = 'successful'; driftsCount = 0
                    runInitiationDateTime = $script:now.AddHours(-2).ToString('o'); runCompletionDateTime = $script:now.AddHours(-2).AddMinutes(3).ToString('o')
                })
            $script:runsFail = $false
            $script:newDrift = {
                param([string] $MonitorId = 'mon-1')
                [pscustomobject]@{
                    id = [guid]::NewGuid().Guid; monitorId = $MonitorId; status = 'active'
                    resourceType = 'microsoft.entra.conditionalaccesspolicy'; baselineResourceDisplayName = 'Block legacy authentication'
                    resourceInstanceIdentifier = [pscustomobject]@{ DisplayName = 'Block legacy authentication'; Id = [guid]::NewGuid().Guid }
                    firstReportedDateTime = $script:now.AddDays(-3).ToString('o')
                    driftedProperties = @([pscustomobject]@{ propertyName = 'State'; currentValue = 'disabled'; desiredValue = 'enabled' })
                }
            }
            Mock Invoke-MtGraphRequest {
                switch ($RelativeUri) {
                    'admin/configurationManagement/configurationDrifts' { $script:drifts }
                    'admin/configurationManagement/configurationMonitoringResults' {
                        if ($script:runsFail) { throw 'Service unavailable' }
                        $script:runs
                    }
                    default { throw "Unexpected Graph call: $RelativeUri" }
                }
            }
            Mock Add-MtTestResultDetail { }
        }
    }

    It 'Passes an active monitor that ran on schedule and reports no drift' {
        InModuleScope Maester {
            Test-MtEntraTenantConfigurationDrift -Instance $script:instance | Should -BeTrue
            Should -Invoke Add-MtTestResultDetail -Times 1 -Exactly -ParameterFilter { -not $Investigate -and $Result -like 'Well done.*' }
        }
    }

    It 'Fails on an active drift of the monitor and shows the current and desired value' {
        InModuleScope Maester {
            $script:drifts = @(& $script:newDrift)
            Test-MtEntraTenantConfigurationDrift -Instance $script:instance | Should -BeFalse
            Should -Invoke Add-MtTestResultDetail -Times 1 -Exactly -ParameterFilter {
                -not $Investigate -and $Result -like '*Block legacy authentication*' -and $Result.Contains('| State | `disabled` | `enabled` |')
            }
        }
    }

    It 'Links a drifted Entra object with the shared portal link template' {
        InModuleScope Maester {
            $portalUrl = $__MtSession.AdminPortalUrl
            try {
                $__MtSession.AdminPortalUrl = @{ Entra = 'https://entra.microsoft.com/' }
                $script:drifts = @(& $script:newDrift)
                $script:policyId = $script:drifts[0].resourceInstanceIdentifier.Id
                Test-MtEntraTenantConfigurationDrift -Instance $script:instance | Should -BeFalse
                Should -Invoke Add-MtTestResultDetail -Times 1 -Exactly -ParameterFilter {
                    $Result.Contains("[Block legacy authentication]($((Get-MtPortalLinkTemplate).LinkTemplates.ConditionalAccess -f $script:policyId))")
                }
            } finally {
                $__MtSession.AdminPortalUrl = $portalUrl
            }
        }
    }

    It 'Ignores the drift of another monitor' {
        InModuleScope Maester {
            $script:drifts = @(& $script:newDrift -MonitorId 'mon-2')
            Test-MtEntraTenantConfigurationDrift -Instance $script:instance | Should -BeTrue
        }
    }

    It 'Investigates no drift when <Condition>' -ForEach @(
        @{ Condition = 'the monitor is inactive'; Note = '*inactive and no longer detects drift*' }
        @{ Condition = 'the last run failed'; Note = '*did not report success (status: failed)*' }
        @{ Condition = 'the last run was partially successful'; Note = '*did not report success (status: partiallySuccessful)*' }
        @{ Condition = 'the last run status is unknownFutureValue'; Note = '*did not report success (status: unknownFutureValue)*' }
        @{ Condition = 'the last run has no status'; Note = '*did not report success (status: none)*' }
        @{ Condition = 'the last run has no start time'; Note = '*has not run as scheduled*' }
        @{ Condition = 'the monitor is overdue'; Note = '*has not run as scheduled*' }
        @{ Condition = 'the runs cannot be read'; Note = '*runs could not be read*' }
    ) {
        InModuleScope Maester -Parameters @{ Condition = $Condition; Note = $Note } {
            param($Condition, $Note)
            switch ($Condition) {
                'the monitor is inactive' { $script:monitor.status = 'inactive'; $script:monitor.inactivationReason = 'Missing permissions' }
                'the last run failed' { $script:runs[0].runStatus = 'failed' }
                'the last run was partially successful' { $script:runs[0].runStatus = 'partiallySuccessful' }
                'the last run status is unknownFutureValue' { $script:runs[0].runStatus = 'unknownFutureValue' }
                'the last run has no status' { $script:runs[0].runStatus = $null }
                'the last run has no start time' { $script:runs[0].runInitiationDateTime = $null }
                'the monitor is overdue' { $script:runs[0].runInitiationDateTime = $script:now.AddHours(-20).ToString('o') }
                'the runs cannot be read' { $script:runsFail = $true }
            }
            Test-MtEntraTenantConfigurationDrift -Instance $script:instance | Should -BeTrue
            Should -Invoke Add-MtTestResultDetail -Times 1 -Exactly -ParameterFilter { $Investigate -and $Result -like $Note }
        }
    }

    It 'Fails rather than investigates when an overdue monitor reports drift' {
        InModuleScope Maester {
            $script:runs[0].runInitiationDateTime = $script:now.AddHours(-20).ToString('o')
            $script:drifts = @(& $script:newDrift)
            Test-MtEntraTenantConfigurationDrift -Instance $script:instance | Should -BeFalse
            Should -Invoke Add-MtTestResultDetail -Times 1 -Exactly -ParameterFilter { -not $Investigate }
        }
    }

    It 'Waits for the first run of a new monitor instead of calling it overdue' {
        InModuleScope Maester {
            $script:monitor.createdDateTime = $script:now.AddMinutes(-10).ToString('o')
            $script:runs = @()
            Test-MtEntraTenantConfigurationDrift -Instance $script:instance | Should -BeTrue
            Should -Invoke Add-MtTestResultDetail -Times 1 -Exactly -ParameterFilter {
                $Investigate -and $Result -like '*has not run yet*' -and $Result -notlike '*has not run as scheduled*'
            }
        }
    }

    It 'Calls a monitor without runs overdue once two run intervals have passed since its creation' {
        InModuleScope Maester {
            $script:monitor.createdDateTime = $script:now.AddDays(-2).ToString('o')
            $script:runs = @()
            Test-MtEntraTenantConfigurationDrift -Instance $script:instance | Should -BeTrue
            Should -Invoke Add-MtTestResultDetail -Times 1 -Exactly -ParameterFilter { $Investigate -and $Result -like '*has not run as scheduled*' }
        }
    }

    It 'Reads <Days> days of runs for a monitor that runs every <Frequency> h' -ForEach @(
        @{ Frequency = 6; Days = 7 }, @{ Frequency = 168; Days = 15 }
    ) {
        InModuleScope Maester -Parameters @{ Frequency = $Frequency; Days = $Days } {
            param($Frequency, $Days)
            $script:monitor.monitorRunFrequencyInHours = $Frequency
            $since = $script:now.Date.AddDays(-$Days).ToString("yyyy-MM-dd'T'HH:mm:ss'Z'", [cultureinfo]::InvariantCulture)
            Test-MtEntraTenantConfigurationDrift -Instance $script:instance | Should -BeTrue
            Should -Invoke Invoke-MtGraphRequest -Times 1 -Exactly -ParameterFilter {
                $RelativeUri -eq 'admin/configurationManagement/configurationMonitoringResults' -and $Filter -eq "runInitiationDateTime ge $since"
            }
        }
    }

    It 'Skips as not authorized when the drifts cannot be read' {
        InModuleScope Maester {
            Mock Invoke-MtGraphRequest {
                throw [Microsoft.PowerShell.Commands.HttpResponseException]::new('Forbidden', [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]::Forbidden))
            } -ParameterFilter { $RelativeUri -eq 'admin/configurationManagement/configurationDrifts' }
            Test-MtEntraTenantConfigurationDrift -Instance $script:instance | Should -BeNullOrEmpty
            Should -Invoke Add-MtTestResultDetail -Times 1 -Exactly -ParameterFilter { $SkippedBecause -eq 'NotAuthorized' }
        }
    }

    It 'Escapes the inactivation reason' {
        InModuleScope Maester {
            $script:monitor.status = 'inactive'
            $script:monitor.inactivationReason = '[Sign in](https://phish.example)'
            Test-MtEntraTenantConfigurationDrift -Instance $script:instance | Should -BeTrue
            Should -Invoke Add-MtTestResultDetail -Times 1 -Exactly -ParameterFilter { $Result.Contains('Sign in') -and -not $Result.Contains('[Sign in](https://phish.example)') }
        }
    }
}

Describe 'MT.1254 monitor instances' {
    BeforeEach {
        InModuleScope Maester {
            $script:monitors = @(
                [pscustomobject]@{ id = 'mon-b'; displayName = 'Baseline B' }
                [pscustomobject]@{ id = $null; displayName = 'Without ID' }
                [pscustomobject]@{ id = 'mon-a'; displayName = 'Baseline A' }
            )
            Mock Get-MgContext { [pscustomobject]@{ Environment = 'Global' } }
            Mock Invoke-MtGraphRequest { $script:monitors }
            Mock Add-MtTestResultDetail { }
        }
    }

    It 'Returns one instance per monitor, sorted by name, and ignores entries without an ID' {
        InModuleScope Maester {
            $instances = @(Get-MtTenantConfigurationMonitorInstance)
            $instances.Id | Should -Be @('mon-a', 'mon-b')
            $instances[0].Title | Should -BeLike "*'Baseline A'*"
        }
    }

    It 'Returns no instance when the tenant has no monitor' {
        InModuleScope Maester {
            $script:monitors = @()
            Get-MtTenantConfigurationMonitorInstance | Should -BeNullOrEmpty
            Should -Invoke Add-MtTestResultDetail -Times 0 -Exactly
        }
    }

    It 'Skips the family as not authorized on HTTP <Code>' -ForEach @(
        @{ Code = 401 }, @{ Code = 403 }
    ) {
        InModuleScope Maester -Parameters @{ Code = $Code } {
            param($Code)
            Mock Invoke-MtGraphRequest {
                throw [Microsoft.PowerShell.Commands.HttpResponseException]::new('Denied', [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]$Code))
            }
            { Get-MtTenantConfigurationMonitorInstance } | Should -Not -Throw
            Should -Invoke Add-MtTestResultDetail -Times 1 -Exactly -ParameterFilter { $SkippedBecause -eq 'NotAuthorized' }
        }
    }

    It 'Propagates other errors' {
        InModuleScope Maester {
            Mock Invoke-MtGraphRequest { throw 'Service unavailable' }
            { Get-MtTenantConfigurationMonitorInstance } | Should -Throw '*Service unavailable*'
        }
    }

    It 'Skips the family outside the worldwide cloud without calling Graph' {
        InModuleScope Maester {
            Mock Get-MgContext { [pscustomobject]@{ Environment = 'USGov' } }
            Get-MtTenantConfigurationMonitorInstance | Should -BeNullOrEmpty
            Should -Invoke Add-MtTestResultDetail -Times 1 -Exactly -ParameterFilter { $SkippedBecause -eq 'Custom' -and $SkippedCustomReason -like '*USGov*' }
            Should -Invoke Invoke-MtGraphRequest -Times 0 -Exactly
        }
    }
}
