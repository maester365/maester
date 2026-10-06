BeforeAll {
    Import-Module "$PSScriptRoot/../../../Maester.psd1" -Force -WarningAction SilentlyContinue

    # The five built-in families (design section 10) run offline: Graph is forced connected through the run
    # config, licences stay Unknown (never a skip), and the data each instance source reads is mocked.
    $script:runConfig = [pscustomobject]@{ Environment = [pscustomobject]@{ Services = [pscustomobject]@{ Graph = $true } } }

    # The 2.x result row's Id and Title from an expanded It name (ConvertTo-MtMaesterResult): strip the
    # "See https" suffix, then split on the first colon.
    function ConvertFrom-ItName {
        param([string] $Name)
        $start = $Name.IndexOf('See https')
        if ($start -gt 0) { $Name = $Name.Substring(0, $start).Trim() }
        $colon = $Name.IndexOf(':')
        [pscustomobject]@{ Id = $Name.Substring(0, $colon).Trim(); Title = $Name.Substring($colon + 1).Trim() }
    }

    function Invoke-Family {
        param([string] $Id)
        Push-Location $TestDrive
        try { @(Invoke-MtTest -Id $Id -Config $script:runConfig 3>$null 6>$null) } finally { Pop-Location }
    }
}

Describe 'Built-in families' {
    BeforeAll {
        # Isolate from the shipped maester-config.json: its 2.x rows (MT.1033.0, MT.1059, ...) are parent or
        # instance settings under the native engine and would override the severities checked here.
        Mock -ModuleName Maester Get-MtShippedMaesterConfig { [pscustomobject]@{} }
    }

    Context 'MT.1024 (Entra recommendations)' {
        BeforeAll {
            $script:recommendations = @(
                @{ id = '11111111-2222-3333-4444-555555555555_userRiskPolicy'; displayName = 'Protect your users from risky sign-ins'; priority = 'high'; status = 'active'; recommendationType = 'userRiskPolicy'; impactedResources = @(@{ status = 'active'; displayName = 'Adele'; subjectId = 'u1' }); insights = 'x'; benefits = 'b'; actionSteps = @() }
                @{ id = '11111111-2222-3333-4444-555555555555_mfaRegistrationV2'; displayName = 'Require multifactor authentication'; priority = 'medium'; status = 'completedBySystem'; recommendationType = 'mfaRegistrationV2'; impactedResources = @(); insights = 'y'; benefits = 'b'; actionSteps = @() }
                @{ id = '11111111-2222-3333-4444-555555555555_staleApps'; displayName = 'Remove unused applications'; priority = 'low'; status = 'dismissed'; recommendationType = 'staleApps'; impactedResources = @(); insights = 'z'; benefits = 'b'; actionSteps = @() }
            )
            Mock -ModuleName Maester Invoke-MtGraphRequest { @{ value = $script:recommendations } } -ParameterFilter { $RelativeUri -like 'directory/recommendations*' }
            Mock -ModuleName Maester Get-MtLicenseInformation { 'P2' }
            Mock -ModuleName Maester Get-MtEmergencyAccessAccount { }
            $script:rows = Invoke-Family 'MT.1024'
        }

        It 'Produces the 2.x instance IDs, titles and severities' {
            $textInfo = (Get-Culture).TextInfo
            foreach ($r in $script:recommendations) {
                # The 2.x It name, with the expressions of Test-EntraRecommendations.Tests.ps1.
                $legacy = ConvertFrom-ItName "MT.1024.$($r.id -replace '^[^_]+_', ''): $($r.displayName). See https://maester.dev/docs/tests/MT.1024"
                $row = $script:rows | Where-Object Id -EQ $legacy.Id
                $row | Should -HaveCount 1 -Because $legacy.Id
                $row.Title | Should -BeExactly $legacy.Title
                $row.Severity | Should -BeExactly $textInfo.ToTitleCase($r.priority)
                $row.ParentId | Should -Be 'MT.1024'
                $row.Tag | Should -Contain $r.recommendationType
            }
        }

        It 'Keeps the 2.x verdicts' {
            ($script:rows | Where-Object Id -EQ 'MT.1024.userRiskPolicy').Result | Should -Be 'Failed'
            ($script:rows | Where-Object Id -EQ 'MT.1024.mfaRegistrationV2').Result | Should -Be 'Passed'
            ($script:rows | Where-Object Id -EQ 'MT.1024.staleApps').Result | Should -Be 'Skipped'
        }
    }

    Context 'MT.1033 and MT.1034 (Conditional Access What If, per user)' {
        BeforeAll {
            $script:members = @(
                @{ id = '00000000-0000-0000-0000-000000000000'; userPrincipalName = 'adele@contoso.com'; userType = 'Member' }
                @{ id = '00000000-0000-0000-0000-0000000000b1'; userPrincipalName = 'breakglass1@contoso.com'; userType = 'Member' }
                @{ id = '00000000-0000-0000-0000-000000000002'; userPrincipalName = 'alex@contoso.com'; userType = 'Member' }
            )
            $script:emergency = @(
                @{ id = '00000000-0000-0000-0000-0000000000b1'; userPrincipalName = 'breakglass1@contoso.com'; userType = 'EmergencyAccess' }
                @{ id = '00000000-0000-0000-0000-0000000000b2'; userPrincipalName = 'breakglass2@contoso.com'; userType = 'EmergencyAccess' }
            )
            Mock -ModuleName Maester Get-MtUser { $script:members } -ParameterFilter { $UserType -eq 'Member' }
            Mock -ModuleName Maester Get-MtUser { $script:emergency } -ParameterFilter { $UserType -eq 'EmergencyAccess' }
            Mock -ModuleName Maester Test-MtCaWIFBlockLegacyAuthentication { $UserId -ne '00000000-0000-0000-0000-000000000002' }
            Mock -ModuleName Maester Test-MtConditionalAccessWhatIf { if ($UserId -eq '00000000-0000-0000-0000-0000000000b2') { [pscustomobject]@{ id = 'p1'; displayName = 'Block all'; policyApplies = $true } } }
            $script:rows1033 = Invoke-Family 'MT.1033'
            $script:rows1034 = Invoke-Family 'MT.1034'
        }

        It 'Produces the 2.x MT.1033 instance IDs and titles (emergency access users excluded)' {
            # 2.x: $RegularUsers (members minus emergency access users) and "MT.1033.$($RegularUsers.IndexOf($_)): ..."
            $regular = @($script:members | Where-Object { $_.id -notin $script:emergency.id })
            $expected = foreach ($u in $regular) { ConvertFrom-ItName "MT.1033.$($regular.IndexOf($u)): User should be blocked from using legacy authentication ($($u.userPrincipalName))" }
            @($script:rows1033.Id) | Should -Be @($expected.Id)
            @($script:rows1033.Title) | Should -Be @($expected.Title)
            $script:rows1033.Severity | Sort-Object -Unique | Should -Be 'High'
            ($script:rows1033 | Where-Object Id -EQ 'MT.1033.0').Result | Should -Be 'Passed'
            ($script:rows1033 | Where-Object Id -EQ 'MT.1033.1').Result | Should -Be 'Failed'
        }

        It 'Produces the 2.x MT.1034 instance IDs and titles' {
            $expected = foreach ($u in $script:emergency) { ConvertFrom-ItName "MT.1034.$($script:emergency.IndexOf($u)): Emergency access users should not be blocked ($($u.userPrincipalName))" }
            @($script:rows1034.Id) | Should -Be @($expected.Id)
            @($script:rows1034.Title) | Should -Be @($expected.Title)
            $script:rows1034.Severity | Sort-Object -Unique | Should -Be 'High'
            ($script:rows1034 | Where-Object Id -EQ 'MT.1034.0').Result | Should -Be 'Passed'
            ($script:rows1034 | Where-Object Id -EQ 'MT.1034.1').Result | Should -Be 'Failed'
        }
    }

    Context 'MT.1059 (Defender for Identity health issues)' {
        BeforeAll {
            $script:healthIssues = @(
                @{ displayName = 'Sensor stopped'; severity = 'high'; status = 'open'; createdDateTime = '2026-01-02'; domainNames = @(); sensorDNSNames = @('dc1.contoso.com'); recommendations = @('Restart the sensor'); additionalInformation = $null }
                @{ displayName = 'Sensor stopped'; severity = 'high'; status = 'closed'; createdDateTime = '2026-01-01'; domainNames = @(); sensorDNSNames = @('dc2.contoso.com'); recommendations = @('Restart the sensor'); additionalInformation = $null }
                @{ displayName = 'Auditing not configured'; severity = 'low'; status = 'closed'; createdDateTime = '2026-01-01'; domainNames = @('contoso.com'); sensorDNSNames = @(); recommendations = @('Configure auditing'); additionalInformation = $null }
            )
            Mock -ModuleName Maester Invoke-MtGraphRequest { @{ value = $script:healthIssues } } -ParameterFilter { $RelativeUri -eq 'security/identities/healthIssues' }
            $script:rows = Invoke-Family 'MT.1059'
        }

        It 'Produces the 2.x instance IDs, titles and severities' {
            $md5 = [System.Security.Cryptography.MD5]::Create()
            $textInfo = (Get-Culture).TextInfo
            foreach ($name in ($script:healthIssues.displayName | Sort-Object -Unique)) {
                $hash = [System.BitConverter]::ToString($md5.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($name))).ToLower() -replace '-', ''
                $legacy = ConvertFrom-ItName "MT.1059.$($hash): MDI Health Issues - $($name). See https://maester.dev/docs/tests/MT.1059"
                $row = $script:rows | Where-Object Id -EQ $legacy.Id
                $row | Should -HaveCount 1 -Because $legacy.Id
                $row.Title | Should -BeExactly $legacy.Title
                $severity = $textInfo.ToTitleCase(($script:healthIssues | Where-Object displayName -EQ $name | Select-Object -First 1).severity)
                $row.Severity | Should -BeExactly $severity
                $row.Tag | Should -Contain "Severity:$severity"
                $row.Tag | Should -Contain $name
            }
        }

        It 'Fails an issue with an open sensor and passes a resolved one' {
            ($script:rows | Where-Object Title -Like '*Sensor stopped*').Result | Should -Be 'Failed'
            ($script:rows | Where-Object Title -Like '*Auditing not configured*').Result | Should -Be 'Passed'
        }
    }

    Context 'MT.1060 (drift folders)' {
        BeforeAll {
            $script:driftRoot = Join-Path $TestDrive 'drift'
            foreach ($folder in 'Policy A', 'ok') { $null = New-Item -ItemType Directory -Path (Join-Path $script:driftRoot $folder) -Force }
            '{"a":1,"b":2}' | Set-Content (Join-Path $script:driftRoot 'Policy A/baseline.json')
            '{"a":3}' | Set-Content (Join-Path $script:driftRoot 'Policy A/current.json')
            '{"a":1}' | Set-Content (Join-Path $script:driftRoot 'ok/baseline.json')
            '{"a":1}' | Set-Content (Join-Path $script:driftRoot 'ok/current.json')
            $script:savedDrift = $env:MAESTER_FOLDER_DRIFT
            $env:MAESTER_FOLDER_DRIFT = $script:driftRoot
            $script:rows = Invoke-Family 'MT.1060'
        }
        AfterAll { $env:MAESTER_FOLDER_DRIFT = $script:savedDrift }

        It 'Names instances MT.1060.folder.n with the folder name sanitised, and keeps the 2.x titles and tags' {
            $titles = @{ 1 = "Drift baseline in '{0}' is valid JSON"; 2 = "Drift current in '{0}' is valid JSON"; 3 = "Drift current in '{0}' has no missing properties"; 4 = "Drift all values in '{0}' match" }
            foreach ($folder in @(@{ Name = 'Policy A'; Safe = 'Policy_A' }, @{ Name = 'ok'; Safe = 'ok' })) {
                foreach ($n in 1..4) {
                    $row = $script:rows | Where-Object Id -EQ "MT.1060.$($folder.Safe).$n"
                    $row | Should -HaveCount 1 -Because "MT.1060.$($folder.Safe).$n"
                    # 2.x: "MT1060.<_.Name>.<n>: <title>" with the same title.
                    $row.Title | Should -BeExactly ($titles[$n] -f $folder.Name)
                    $row.ParentId | Should -Be 'MT.1060'
                    foreach ($tag in 'MT1060', "MT1060.$n", "MT1060.$($folder.Name)", "MT1060.$($folder.Name).$n") { $row.Tag | Should -Contain $tag }
                }
            }
        }

        It 'Reports drift' {
            ($script:rows | Where-Object Id -EQ 'MT.1060.Policy_A.3').Result | Should -Be 'Failed'
            ($script:rows | Where-Object Id -EQ 'MT.1060.Policy_A.4').Result | Should -Be 'Failed'
            @($script:rows | Where-Object Id -Like 'MT.1060.ok.*' | Where-Object Result -NE 'Passed') | Should -HaveCount 0
        }
    }
}

Describe 'Family instance sources that return nothing or fail' {
    BeforeAll {
        Mock -ModuleName Maester Get-MtShippedMaesterConfig { [pscustomobject]@{} }
        Mock -ModuleName Maester Invoke-MtGraphRequest { @{ value = @() } }
        Mock -ModuleName Maester Get-MtUser { }
    }

    It '<Id> gives one NoInstances row on the parent ID when the source is empty' -ForEach @(
        @{ Id = 'MT.1024' }, @{ Id = 'MT.1033' }, @{ Id = 'MT.1034' }, @{ Id = 'MT.1059' }, @{ Id = 'MT.1060' }
    ) {
        $saved = $env:MAESTER_FOLDER_DRIFT
        $env:MAESTER_FOLDER_DRIFT = $null
        try { $rows = Invoke-Family $Id } finally { $env:MAESTER_FOLDER_DRIFT = $saved }
        $rows | Should -HaveCount 1
        $rows[0].Id | Should -Be $Id
        $rows[0].Result | Should -Be 'Skipped'
        $rows[0].ReasonCode | Should -Be 'NoInstances'
    }

    It '<Id> gives one InstanceSourceFailed row on the parent ID when the source throws' -ForEach @(
        @{ Id = 'MT.1024' }, @{ Id = 'MT.1033' }, @{ Id = 'MT.1034' }, @{ Id = 'MT.1060' }
    ) {
        Mock -ModuleName Maester Invoke-MtGraphRequest { throw 'Graph is down' }
        Mock -ModuleName Maester Get-MtUser { throw 'Graph is down' }
        $driftRoot = Join-Path $TestDrive 'failing-drift'
        $null = New-Item -ItemType Directory -Path (Join-Path $driftRoot 'one') -Force
        Mock -ModuleName Maester Get-ChildItem { throw 'Disk is down' } -ParameterFilter { $LiteralPath -eq $driftRoot }
        $saved = $env:MAESTER_FOLDER_DRIFT
        $env:MAESTER_FOLDER_DRIFT = $driftRoot
        try { $rows = Invoke-Family $Id } finally { $env:MAESTER_FOLDER_DRIFT = $saved }
        $rows | Should -HaveCount 1
        $rows[0].Id | Should -Be $Id
        $rows[0].Result | Should -Be 'Error'
        $rows[0].ReasonCode | Should -Be 'InstanceSourceFailed'
    }

    It 'MT.1059 is skipped, not an error, when Defender for Identity health issues cannot be read' {
        # 2.x showed no rows when Defender for Identity is not enabled; the run must not fail because of it.
        Mock -ModuleName Maester Invoke-MtGraphRequest { throw 'Resource not found' }
        $rows = Invoke-Family 'MT.1059'
        $rows | Should -HaveCount 1
        $rows[0].Id | Should -Be 'MT.1059'
        $rows[0].Result | Should -Be 'Skipped'
        $rows[0].ReasonCode | Should -Be 'TestSkipped'
        $rows[0].ReasonDetail | Should -BeLike '*Defender for Identity*'
        [Maester.Engine.MtSession]::GetCurrentTest() | Should -BeNullOrEmpty
    }
}
