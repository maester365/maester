Describe 'Zero Trust Assessment pack' {
    BeforeAll {
        Import-Module $PSScriptRoot/../../Maester.psd1 -Force -WarningAction SilentlyContinue
        $script:PackRoot = (Resolve-Path "$PSScriptRoot/../../../packs/zero-trust-assessment").Path
        $script:TestsPath = Join-Path $script:PackRoot 'tests'
        $script:Fixture = (Resolve-Path "$PSScriptRoot/../fixtures/zero-trust-assessment").Path

        # The fixture is a cut of the assessment's own sample report: two rows of each status, a Defender for
        # Cloud ID that repeats with different titles, and one row that repeats exactly.
        function Invoke-ZtaPack {
            param([hashtable] $Setting = @{})
            $globalSettings = @{ 'ZeroTrustAssessment.ReportPath' = $script:Fixture; 'ZeroTrustAssessment.MaxReportAgeDays' = 0 }
            foreach ($key in $Setting.Keys) { $globalSettings[$key] = $Setting[$key] }
            $config = [pscustomobject]@{
                GlobalSettings = [pscustomobject]$globalSettings
                Environment    = [pscustomobject]@{ Enforce = [pscustomobject]@{ Service = $false } }
            }
            @(Invoke-MtTest -Path $script:TestsPath -Id ZTA -Config $config)
        }

        $script:Rows = Invoke-ZtaPack

        # The attachments the last run added, or nothing on a Maester version without Add-MtReportAttachment.
        function Get-ZtaAttachment {
            InModuleScope Maester { @($__MtSession.ReportAttachments | Where-Object { $_ }) }
        }
        function Clear-ZtaAttachment {
            InModuleScope Maester { $__MtSession.ReportAttachments = $null }
        }
        $script:CanAttach = [bool](Get-Command -Name Add-MtReportAttachment -ErrorAction Ignore)
    }

    AfterEach {
        # Removes only the stand-in a test defined, never a Get-MgContext a module exports.
        Get-Item -Path function:Get-MgContext -ErrorAction SilentlyContinue | Where-Object { -not $_.Module } | Remove-Item
    }

    Context 'the pack files' {
        It 'has a valid native test' {
            $test = Get-MtTest -Path (Join-Path $script:TestsPath 'Test.ZTA.ps1')
            $test.IsValid | Should -BeTrue
            $test.Errors | Should -BeNullOrEmpty
            $test.LongRunning | Should -BeTrue
            $test.InstanceSource | Should -Be 'Get-MtZtaInstance'
            $test.Suite | Should -Be 'ZTA'
        }

        It 'has a manifest with the pack code' {
            $manifest = Get-Content (Join-Path $script:PackRoot 'maester-pack.json') -Raw | ConvertFrom-Json
            $manifest.Id | Should -Be 'maester.zero-trust-assessment'
            $manifest.Code | Should -Be 'ZTA'
            $manifest.Uses.GraphScopes | Should -Be @($manifest.Uses.GraphScopes | Sort-Object -Unique)
        }

        It 'has a catalog of unique ZTA IDs' {
            $catalog = Get-Content (Join-Path $script:PackRoot 'catalog.json') -Raw | ConvertFrom-Json
            $catalog.ModuleVersion | Should -Not -BeNullOrEmpty
            $catalog.Tests.Count | Should -BeGreaterThan 0
            @($catalog.Tests.Id | Where-Object { $_ -notmatch '^ZTA\.\d+$' }) | Should -BeNullOrEmpty
            @($catalog.Tests.Id | Sort-Object -Unique).Count | Should -Be $catalog.Tests.Count
            @($catalog.Tests | Where-Object { [string]::IsNullOrWhiteSpace($_.Title) }) | Should -BeNullOrEmpty
        }

        It 'has the description and remediation of the tests the module documents' {
            $catalog = Get-Content (Join-Path $script:PackRoot 'catalog.json') -Raw | ConvertFrom-Json
            @($catalog.Tests | Where-Object { -not $_.PSObject.Properties['Description'] -or -not $_.PSObject.Properties['Remediation'] }).Id | Should -BeNullOrEmpty
            @($catalog.Tests | Where-Object Description).Count | Should -BeGreaterThan ($catalog.Tests.Count / 2) -Because 'catalog.json is written from the module with build/zta/Update-MtZtaCatalog.ps1'
            @($catalog.Tests | Where-Object { $_.Description -match '<!---\s*Results' -or $_.Remediation -match '%TestResult%' }).Id | Should -BeNullOrEmpty
        }

        It 'carries the module''s MIT copyright and permission notice with the text it copies' {
            $catalog = Get-Content (Join-Path $script:PackRoot 'catalog.json') -Raw | ConvertFrom-Json
            $catalog.License | Should -Match 'Copyright \(c\) Microsoft Corporation'
            $catalog.License | Should -Match 'Permission is hereby granted'
        }

        It 'maps every test of the catalog, and only those, in taxonomy.json' {
            $catalog = Get-Content (Join-Path $script:PackRoot 'catalog.json') -Raw | ConvertFrom-Json
            $mapping = (Get-Content (Join-Path $script:PackRoot 'taxonomy.json') -Raw | ConvertFrom-Json -AsHashtable).Tests
            @($catalog.Tests.TestId | Where-Object { -not $mapping.ContainsKey([string]$_) }) | Should -BeNullOrEmpty -Because 'a test the assessment added needs a mapping: add it to taxonomy.json and run build/zta/Update-MtZtaCatalog.ps1'
            @($mapping.Keys | Where-Object { $_ -notin @($catalog.Tests.TestId) }) | Should -BeNullOrEmpty -Because 'a test the assessment removed is left in taxonomy.json'
        }

        It 'copies the mapping into the catalog' {
            $catalog = Get-Content (Join-Path $script:PackRoot 'catalog.json') -Raw | ConvertFrom-Json
            $mapping = (Get-Content (Join-Path $script:PackRoot 'taxonomy.json') -Raw | ConvertFrom-Json -AsHashtable).Tests
            $stale = foreach ($entry in $catalog.Tests) {
                $map = $mapping[[string]$entry.TestId]
                if (-not $map) { continue }
                if ($entry.Product -ne $map.Product -or $entry.Feature -ne $map.Feature -or $entry.Area -ne $map.Area -or (@($entry.Mitre) -join ',') -ne (@($map.Mitre) -join ',')) { $entry.Id }
            }
            @($stale) | Should -BeNullOrEmpty -Because 'catalog.json is written from taxonomy.json: run build/zta/Update-MtZtaCatalog.ps1'
        }

        It 'uses only keys of the taxonomy and techniques of the pinned ATT&CK release' {
            $mapping = (Get-Content (Join-Path $script:PackRoot 'taxonomy.json') -Raw | ConvertFrom-Json -AsHashtable).Tests
            $problems = InModuleScope Maester -Parameters @{ Mapping = $mapping } {
                param($Mapping)
                $taxonomy = Get-MtTaxonomy
                foreach ($id in $Mapping.Keys) {
                    $map = $Mapping[$id]
                    $features = $null
                    if (-not $taxonomy.Lookup.Product.ContainsKey([string]$map.Product) -or $taxonomy.Lookup.Product[[string]$map.Product].Key -ne $map.Product) { "$id has the unknown product '$($map.Product)'."; continue }
                    if (-not ($taxonomy.Lookup.Feature.TryGetValue($map.Product, [ref] $features) -and $features.ContainsKey([string]$map.Feature))) { "$id has the feature '$($map.Feature)', which $($map.Product) does not have." }
                    if (-not $taxonomy.Lookup.Area.ContainsKey([string]$map.Area)) { "$id has the unknown area '$($map.Area)'." }
                    foreach ($related in @($map.RelatedProduct | Where-Object { $_ })) {
                        if ($related -eq $map.Product -or -not $taxonomy.Lookup.Product.ContainsKey($related)) { "$id has the related product '$related'." }
                    }
                    $mitre = @($map.Mitre | Where-Object { $_ })
                    if (-not $mitre.Count) { "$id has no Mitre value; use None when no technique applies." }
                    elseif ($mitre.Count -gt 5) { "$id lists more than five techniques." }
                    if ($mitre -contains 'None' -and $mitre.Count -gt 1) { "$id lists None with techniques." }
                    foreach ($problem in Get-MtAttackTechniqueProblem -Mitre $mitre) { "${id}: $problem" }
                    foreach ($technique in $mitre) {
                        if ($technique -match '^(T\d{4})\.\d{3}$' -and $mitre -contains $Matches[1]) { "$id lists $technique with its own technique $($Matches[1])." }
                    }
                }
            }
            @($problems) | Should -BeNullOrEmpty
        }

        It 'names only built-in tests that exist in AlsoCheckedBy' {
            $mapping = (Get-Content (Join-Path $script:PackRoot 'taxonomy.json') -Raw | ConvertFrom-Json -AsHashtable).Tests
            $repository = (Resolve-Path "$PSScriptRoot/../../..").Path
            $known = @{}
            foreach ($file in Get-ChildItem -Path (Join-Path $repository 'tests') -Recurse -Filter 'Test.*.ps1') { $known[$file.BaseName.Substring(5)] = $true }
            $missing = foreach ($id in $mapping.Keys) {
                foreach ($other in @($mapping[$id].AlsoCheckedBy | Where-Object { $_ })) { if (-not $known.ContainsKey($other)) { "$id names $other" } }
            }
            @($missing) | Should -BeNullOrEmpty
        }
    }

    Context 'reading a report' {
        It 'writes one row per assessment result and leaves out planned tests' {
            $script:Rows.Count | Should -Be 12
            $script:Rows.Id | Should -Not -Contain 'ZTA.21821'
            $script:Rows.Id | Should -Not -Contain 'ZTA.21894'
            @($script:Rows | Where-Object ParentId -ne 'ZTA') | Should -BeNullOrEmpty
        }

        It 'maps <Id> to <Result>' -ForEach @(
            @{ Id = 'ZTA.24542'; Result = 'Passed' }
            @{ Id = 'ZTA.21828'; Result = 'Failed' }
            @{ Id = 'ZTA.25481'; Result = 'Investigate' }
            @{ Id = 'ZTA.21955'; Result = 'Skipped' }
            @{ Id = 'ZTA.24548'; Result = 'Error' }
        ) {
            ($script:Rows | Where-Object Id -eq $Id).Result | Should -Be $Result
        }

        It 'keeps the assessment title, risk level and pillar' {
            $row = $script:Rows | Where-Object Id -eq 'ZTA.21828'
            $row.Title | Should -Be 'Authentication transfer is blocked'
            $row.Severity | Should -Be 'High'
            $row.Tag | Should -Contain 'ZeroTrust.Identity'
            $row.ResultDetail.TestDescription | Should -BeLike 'Blocking authentication transfer*'
            $row.ResultDetail.TestResult | Should -BeLike '*Authentication transfer is not blocked.*'
        }

        It 'places a result under the product, feature, area and techniques of the mapping' {
            $map = (Get-Content (Join-Path $script:PackRoot 'taxonomy.json') -Raw | ConvertFrom-Json -AsHashtable).Tests['21828']
            $row = $script:Rows | Where-Object Id -eq 'ZTA.21828'
            $row.Product | Should -Be $map.Product
            $row.Feature | Should -Be $map.Feature
            $row.Area | Should -Be $map.Area
            @($row.Mitre) | Should -Be @($map.Mitre)
        }

        It 'uses Maester wording for a skip reason both tools share' {
            ($script:Rows | Where-Object Id -eq 'ZTA.21955').ReasonCode | Should -Be 'NotApplicable'
        }

        It 'gives rows that share an ID a stable suffix from their title' {
            $guidRows = @($script:Rows | Where-Object Id -like 'ZTA.55555555-5555-5555-5555-555555555555.*')
            $guidRows.Count | Should -Be 3
            @($guidRows.Id | Sort-Object -Unique).Count | Should -Be 3
            $guidRows.Id | Should -Contain 'ZTA.55555555-5555-5555-5555-555555555555.1b7e76ce09'
            $guidRows.Id | Should -Contain 'ZTA.55555555-5555-5555-5555-555555555555.1b7e76ce09.2'
            $script:Rows.Id | Should -Contain 'ZTA.77777777-7777-7777-7777-777777777777'
        }

        It 'embeds the assessment HTML report written beside the export' {
            if (-not $script:CanAttach) { Set-ItResult -Skipped -Because 'this Maester has no Add-MtReportAttachment' }
            $folder = New-Item -ItemType Directory -Path (Join-Path -Path $TestDrive -ChildPath 'zt' -AdditionalChildPath 'zt-export') -Force
            Copy-Item -LiteralPath (Join-Path $script:Fixture 'ZeroTrustAssessmentReport.json') -Destination $folder
            Set-Content -LiteralPath (Join-Path $TestDrive 'zt/ZeroTrustAssessmentReport.html') -Value '<html>zta</html>'
            Clear-ZtaAttachment

            $null = Invoke-ZtaPack -Setting @{ 'ZeroTrustAssessment.ReportPath' = (Join-Path $folder 'ZeroTrustAssessmentReport.json') }

            $attachment = @(Get-ZtaAttachment)
            $attachment.Count | Should -Be 1
            $attachment[0].Name | Should -Be 'Zero Trust Assessment'
            $attachment[0].TestId | Should -Be 'ZTA'
            $attachment[0].FileName | Should -Be 'ZeroTrustAssessmentReport.html'
        }

        It 'embeds nothing when the report has no HTML beside it, or when EmbedReport is false' {
            if (-not $script:CanAttach) { Set-ItResult -Skipped -Because 'this Maester has no Add-MtReportAttachment' }
            Clear-ZtaAttachment
            $null = Invoke-ZtaPack
            Get-ZtaAttachment | Should -BeNullOrEmpty

            $null = Invoke-ZtaPack -Setting @{ 'ZeroTrustAssessment.ReportPath' = (Join-Path $TestDrive 'zt'); 'ZeroTrustAssessment.EmbedReport' = $false }
            Get-ZtaAttachment | Should -BeNullOrEmpty
        }

        It 'skips the family when the report is missing' {
            $rows = Invoke-ZtaPack -Setting @{ 'ZeroTrustAssessment.ReportPath' = (Join-Path $TestDrive 'none') }
            $rows.Count | Should -Be 1
            $rows[0].Result | Should -Be 'Skipped'
            $rows[0].ReasonDetail | Should -BeLike '*No Zero Trust Assessment report was found*'
        }

        It 'skips the family when the report is too old' {
            $rows = Invoke-ZtaPack -Setting @{ 'ZeroTrustAssessment.MaxReportAgeDays' = 7 }
            $rows.Count | Should -Be 1
            $rows[0].Result | Should -Be 'Skipped'
            $rows[0].ReasonDetail | Should -BeLike '*more than 7 days ago*'
        }

        It 'reads the report date the same way in any culture' {
            # A day above 12 cannot be read as a month, so a culture-dependent parse would miss the age check.
            $report = Get-Content -LiteralPath (Join-Path $script:Fixture 'ZeroTrustAssessmentReport.json') -Raw | ConvertFrom-Json
            $report.ExecutedAt = '2026-01-13T00:00:00Z'
            $file = Join-Path $TestDrive 'old-report.json'
            $report | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $file -Encoding utf8
            $culture = [cultureinfo]::CurrentCulture
            try {
                [cultureinfo]::CurrentCulture = [cultureinfo]::GetCultureInfo('en-GB')
                $rows = Invoke-ZtaPack -Setting @{ 'ZeroTrustAssessment.ReportPath' = $file; 'ZeroTrustAssessment.MaxReportAgeDays' = 7 }
            } finally {
                [cultureinfo]::CurrentCulture = $culture
            }
            $rows.Count | Should -Be 1
            $rows[0].ReasonDetail | Should -BeLike '*written on 2026-01-13, more than 7 days ago*'
        }

        It 'skips the family when the report is for another tenant' {
            function global:Get-MgContext { [pscustomobject]@{ TenantId = '00000000-0000-0000-0000-000000000001' } }
            $rows = Invoke-ZtaPack
            $rows.Count | Should -Be 1
            $rows[0].Result | Should -Be 'Skipped'
            $rows[0].ReasonDetail | Should -BeLike '*is for tenant 22222222-2222-2222-2222-222222222222*'
        }
    }

    Context 'facts from the export' {
        BeforeAll {
            . (Join-Path $script:PackRoot 'helpers/Add-MtZtaObjectFact.ps1')

            # A small export in the assessment's layout: zt-export/<Entity>/<Entity>-<n>.json pages of Graph JSON.
            $script:Export = Join-Path $TestDrive 'facts/zt-export'
            function Write-ZtaExportPage {
                param([string] $Name, [object[]] $Value)
                $folder = New-Item -ItemType Directory -Path (Join-Path $script:Export $Name) -Force
                @{ value = @($Value) } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $folder "$Name-0.json")
                # The model file describes the table and must not be read as data.
                '{ "value": [ { "id": "model" } ] }' | Set-Content -LiteralPath (Join-Path $folder "$Name-model.json")
            }
            $tenant = '11111111-1111-1111-1111-111111111111'
            $graph = '22222222-0000-0000-0000-000000000001'
            Copy-Item -LiteralPath (Join-Path $script:Fixture 'ZeroTrustAssessmentReport.json') -Destination (New-Item -ItemType Directory -Path $script:Export -Force)
            Write-ZtaExportPage ServicePrincipal @(
                @{ id = $graph; appId = '00000003-0000-0000-c000-000000000000'; displayName = 'Microsoft Graph'; appOwnerOrganizationId = 'f8cdef31-a31e-4b4a-93e4-5f571e91255a'
                    appRoles = @(@{ id = 'r1'; value = 'Directory.ReadWrite.All' }, @{ id = 'r2'; value = 'User.Read.All' }); appRoleAssignments = @() }
                @{ id = 'sp-1'; appId = 'app-1'; displayName = 'Contoso sync'; appOwnerOrganizationId = $tenant; accountEnabled = $true
                    appRoleAssignments = @(@{ resourceId = $graph; appRoleId = 'r1' }, @{ resourceId = $graph; appRoleId = 'r2' })
                    oauth2PermissionGrants = @(@{ consentType = 'AllPrincipals'; resourceId = $graph; scope = 'openid User.ReadWrite.All' })
                    passwordCredentials = @(@{ endDateTime = '2027-01-01T00:00:00Z' }, @{ endDateTime = '2025-01-01T00:00:00Z' }) }
            )
            Write-ZtaExportPage ServicePrincipalSignIn @(@{ appId = 'app-1'; lastSignInActivity = @{ lastSignInDateTime = '2026-01-01T00:00:00Z' } })
            Write-ZtaExportPage Application @(@{ id = 'obj-1'; appId = 'app-1'; signInAudience = 'AzureADMultipleOrgs'; owners = @() })
            Write-ZtaExportPage RoleDefinition @(@{ id = 'ga'; templateId = 'ga'; displayName = 'Global Administrator'; isPrivileged = $true })
            Write-ZtaExportPage RoleAssignment @(@{ principalId = 'user-1'; roleDefinitionId = 'ga'; directoryScopeId = '/' })
            Write-ZtaExportPage User @(@{ id = 'user-1'; userType = 'Member'; accountEnabled = $true; signInActivity = @{ lastSignInDateTime = '2026-10-20T00:00:00Z' } })
            Write-ZtaExportPage UserRegistrationDetails @(@{ id = 'user-1'; isMfaRegistered = $false; isAdmin = $true })
            Write-ZtaExportPage ConfigurationPolicy @(@{ id = 'pol-1'; platforms = 'windows10'; technologies = 'mdm'; settingCount = 3; assignments = @() })

            $script:Report = [pscustomobject]@{ TenantId = $tenant; ExecutedAt = '2026-10-23T12:00:00Z' }
            $script:Facts = @(ConvertTo-MtZtaObjectFactRecord -ExportPath $script:Export -Report $script:Report)
            function Get-ZtaFact {
                param([string] $Type, [string] $Id, [string] $Name)
                ($script:Facts | Where-Object { $_.Type -eq $Type -and $_.Id -eq $Id }).Fact | Where-Object Name -EQ $Name
            }
        }

        It 'names an app''s Tier 0 Graph permissions as a risk' {
            $fact = Get-ZtaFact -Type ServicePrincipal -Id sp-1 -Name 'Application permissions'
            $fact.Tone | Should -Be 'Risk'
            $fact.Value | Should -Be 'Directory.ReadWrite.All has a path to Global Administrator. Microsoft Graph: Directory.ReadWrite.All, User.Read.All'
        }

        It 'lists write permissions consented for all users, without openid' {
            $fact = Get-ZtaFact -Type ServicePrincipal -Id sp-1 -Name 'Consented for all users'
            $fact.Value | Should -Be 'Microsoft Graph: User.ReadWrite.All'
            $fact.Tone | Should -Be 'Warning'
        }

        It 'counts active and expired client secrets and dates sign-ins from the assessment' {
            (Get-ZtaFact -Type ServicePrincipal -Id sp-1 -Name 'Client secrets').Value | Should -Be '1 active, the next expires on 2027-01-01; 1 expired'
            $signIn = Get-ZtaFact -Type ServicePrincipal -Id sp-1 -Name 'Last sign-in'
            $signIn.Value | Should -Be '2026-01-01 (295 days before the assessment)'
            $signIn.Tone | Should -Be 'Warning'
        }

        It 'keys an app registration by its appId and gives it the app''s permissions' {
            (Get-ZtaFact -Type AppRegistration -Id app-1 -Name 'Owners').Tone | Should -Be 'Warning'
            (Get-ZtaFact -Type AppRegistration -Id app-1 -Name 'Who can sign in').Value | Should -Be 'Any Microsoft Entra organization'
            (Get-ZtaFact -Type AppRegistration -Id app-1 -Name 'Application permissions').Tone | Should -Be 'Risk'
        }

        It 'names a permanent Global Administrator without MFA as a risk' {
            (Get-ZtaFact -Type User -Id user-1 -Name 'Entra roles').Value | Should -Be 'Global Administrator (permanent)'
            (Get-ZtaFact -Type User -Id user-1 -Name 'Entra roles').Tone | Should -Be 'Risk'
            (Get-ZtaFact -Type User -Id user-1 -Name 'MFA').Tone | Should -Be 'Risk'
            (Get-ZtaFact -Type User -Id user-1 -Name 'Last sign-in').Tone | Should -Be 'Info'
        }

        It 'names an unassigned Intune policy for review' {
            $record = $script:Facts | Where-Object Type -EQ 'ConfigurationPolicy'
            $record.System | Should -Be 'Intune'
            (Get-ZtaFact -Type ConfigurationPolicy -Id pol-1 -Name 'Assignments').Value | Should -Be 'Not assigned'
        }

        It 'gives facts the shared keys and raw values' {
            $raw = {
                param([string] $Type, [string] $Id, [string] $Key)
                (($script:Facts | Where-Object { $_.Type -eq $Type -and $_.Id -eq $Id }).Fact | Where-Object Key -EQ $Key).Raw
            }
            & $raw User user-1 'user.mfaRegistered' | Should -BeFalse
            & $raw User user-1 'user.privilegedRoles' | Should -Be @('Global Administrator')
            & $raw User user-1 'signIn.daysSince' | Should -Be 3
            & $raw ServicePrincipal sp-1 'signIn.daysSince' | Should -Be 295
            & $raw ServicePrincipal sp-1 'app.highPrivilegePermissions' | Should -Be @('Directory.ReadWrite.All')
            & $raw ServicePrincipal sp-1 'app.credentialExpired' | Should -BeTrue
            & $raw AppRegistration app-1 'app.ownerCount' | Should -Be 0
        }

        It 'reads no model file as data' {
            $script:Facts.Id | Should -Not -Contain 'model'
        }

        It 'adds the facts to the run when it collects affected objects, and nothing when ObjectFacts is false' {
            $collect = {
                param([hashtable] $Setting)
                InModuleScope Maester { $__MtSession.IncludeAffectedObjects = $true; $__MtSession.AffectedObjectFacts = $null }
                try {
                    $null = Invoke-ZtaPack -Setting $Setting
                    InModuleScope Maester { if ($__MtSession.AffectedObjectFacts) { @($__MtSession.AffectedObjectFacts.Keys) } }
                } finally {
                    InModuleScope Maester { $__MtSession.IncludeAffectedObjects = $false; $__MtSession.AffectedObjectFacts = $null }
                }
            }
            $report = Join-Path $script:Export 'ZeroTrustAssessmentReport.json'

            $keys = @(& $collect @{ 'ZeroTrustAssessment.ReportPath' = $report })
            $keys | Should -Contain 'EntraID|User|user-1'
            $keys | Should -Contain 'Intune|ConfigurationPolicy|pol-1'

            @(& $collect @{ 'ZeroTrustAssessment.ReportPath' = $report; 'ZeroTrustAssessment.ObjectFacts' = $false }) | Should -BeNullOrEmpty
        }
    }

    Context 'running the assessment' {
        BeforeAll {
            # A stand-in for the ZeroTrustAssessment module: it records what it was called with and writes the
            # fixture report where Invoke-ZtAssessment writes its own.
            $script:FakeModules = Join-Path $TestDrive 'modules'
            $moduleFolder = New-Item -ItemType Directory -Path (Join-Path -Path $script:FakeModules -ChildPath 'ZeroTrustAssessment' -AdditionalChildPath '9.9.9') -Force
            $script:CallLog = Join-Path $TestDrive 'calls.json'
            Set-Content -LiteralPath (Join-Path $moduleFolder 'ZeroTrustAssessment.psd1') -Value "@{ RootModule = 'ZeroTrustAssessment.psm1'; ModuleVersion = '9.9.9'; FunctionsToExport = 'Connect-ZtAssessment', 'Invoke-ZtAssessment', 'Get-PSFDynamicContentObject' }"
            Set-Content -LiteralPath (Join-Path $moduleFolder 'ZeroTrustAssessment.psm1') -Value @"
# The dictionary the real module keeps its progress in, which PSFramework hands out by name.
`$script:State = [pscustomobject]@{ Value = [System.Collections.Concurrent.ConcurrentDictionary[string, object]]::new() }
function Get-PSFDynamicContentObject { [CmdletBinding()] param([string] `$Name) if (`$Name -eq 'ZtAssessment.ProgressState') { `$script:State } }
function Connect-ZtAssessment { param([string] `$TenantId, [string] `$ClientId, `$Certificate, [string[]] `$Service) `$script:Connect = `$PSBoundParameters }
function Invoke-ZtAssessment {
    param([string] `$Path, [string] `$Pillar, [switch] `$NoBrowser, [switch] `$DisableTelemetry, [switch] `$ShowLog, [int] `$Days, [string[]] `$Tests, [string] `$ConfigurationFile)
    Write-Host "Running test 21828"
    Write-Progress -Activity 'Processing 1 Tests' -Status 'Completed: 1 / 1' -PercentComplete 100
    [Console]::Error.WriteLine('a line on stderr')
    if (`$env:MT_ZTA_FAKE_PROGRESS) {
        `$v = `$script:State.Value
        `$v['_stage'] = 'export'; `$v['_stageNumber'] = 1; `$v['_stageName'] = 'Exporting Tenant Data'; `$v['_totalStages'] = 6
        `$v['_totalItems'] = 40; `$v['_completedItems'] = 12; `$v['_failedItems'] = 1; `$v['_inProgressItems'] = 2
        `$v['worker_User'] = [pscustomobject]@{ Id = 'User'; Name = 'User'; Status = 'Running'; Detail = 'Page 3'; StartedAt = '1'; UpdatedAt = '2' }
        `$v['worker_Group'] = [pscustomobject]@{ Id = 'Group'; Name = 'Group'; Status = 'Running'; Detail = ''; StartedAt = '2'; UpdatedAt = '1' }
        `$v['worker_Device'] = [pscustomobject]@{ Id = 'Device'; Name = 'Device'; Status = 'Failed'; Detail = ''; StartedAt = '0'; UpdatedAt = '0' }
        `$logs = New-Item -ItemType Directory -Path (Join-Path `$Path 'zt-export' -AdditionalChildPath 'logs', '26-10-23-101500') -Force
        Set-Content -LiteralPath (Join-Path `$logs '1-export_progress.log') -Value @(
            '2026-10-23 10:15:01.000  STARTED     Device'
            '2026-10-23 10:15:02.000  FAILED      Device  00:00:01.000  Forbidden'
        )
        Start-Sleep -Milliseconds 2500
    }
    `$export = New-Item -ItemType Directory -Path (Join-Path `$Path 'zt-export') -Force
    Copy-Item -LiteralPath '$(Join-Path $script:Fixture 'ZeroTrustAssessmentReport.json')' -Destination `$export
    Set-Content -LiteralPath (Join-Path `$Path 'ZeroTrustAssessmentReport.html') -Value '<html>zta</html>'
    `$config = if (`$ConfigurationFile) { Get-Content -LiteralPath `$ConfigurationFile -Raw | ConvertFrom-Json } else { `$null }
    @{ Connect = `$script:Connect; Assessment = `$PSBoundParameters; Config = `$config } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath '$($script:CallLog)'
}
"@
            $script:OriginalModulePath = $env:PSModulePath
            $env:PSModulePath = $script:FakeModules + [System.IO.Path]::PathSeparator + $env:PSModulePath
        }

        AfterAll {
            $env:PSModulePath = $script:OriginalModulePath
        }

        It 'runs the assessment in a child process and reads its report' {
            $output = Join-Path $TestDrive 'zt-output'
            $rows = Invoke-ZtaPack -Setting @{
                'ZeroTrustAssessment.ReportPath' = ''
                'ZeroTrustAssessment.OutputPath' = $output
                'ZeroTrustAssessment.Pillar'     = 'Identity'
                'ZeroTrustAssessment.Tests'      = @('21828')
                EmergencyAccessAccounts          = @([pscustomobject]@{ Type = 'User'; UserPrincipalName = 'breakglass@contoso.com' })
            }
            $rows.Count | Should -Be 12
            Test-Path (Join-Path -Path $output -ChildPath 'zt-export' -AdditionalChildPath 'ZeroTrustAssessmentReport.json') | Should -BeTrue

            $call = Get-Content -LiteralPath $script:CallLog -Raw | ConvertFrom-Json
            $call.Assessment.Path | Should -Be $output
            $call.Assessment.Pillar | Should -Be 'Identity'
            $call.Assessment.Tests | Should -Be @('21828')
            $call.Assessment.NoBrowser | Should -BeTrue
            $call.Assessment.DisableTelemetry | Should -BeTrue
            $call.Assessment.ShowLog | Should -BeTrue
            # One account is still a list in the assessment's configuration file.
            $call.Config.GlobalSettings.EmergencyAccessAccounts -is [array] | Should -BeTrue
            $call.Config.GlobalSettings.EmergencyAccessAccounts[0].UserPrincipalName | Should -Be 'breakglass@contoso.com'
        }

        It 'shows what the child writes while it runs, its progress as a line of progress' {
            $script:Shown = [System.Collections.Generic.List[object]]::new()
            Mock -ModuleName Maester Write-MtHostLine { $script:Shown.Add($Text) }
            $rows = Invoke-ZtaPack -Setting @{ 'ZeroTrustAssessment.ReportPath' = '' }
            $rows.Count | Should -Be 12
            # A console that shows colour, such as GitHub Actions, gets the lines styled.
            $shown = @($script:Shown -replace "`e\[[0-9;]*m", '')
            $shown | Should -Contain '  Microsoft Zero Trust Assessment 9.9.9'
            $shown | Should -Contain '    Running test 21828'
            $shown | Should -Contain '    Processing 1 Tests: Completed: 1 / 1 (100%)'
            $shown | Should -Contain '    a line on stderr'
            @($shown | Where-Object { $_ -match 'maester-progress' }) | Should -BeNullOrEmpty
        }

        It 'shows the stage, the counts, the items running and the failures the assessment reports' {
            $script:Shown = [System.Collections.Generic.List[object]]::new()
            Mock -ModuleName Maester Write-MtHostLine { $script:Shown.Add($Text) }
            $env:MT_ZTA_FAKE_PROGRESS = '1'
            try {
                $rows = Invoke-ZtaPack -Setting @{ 'ZeroTrustAssessment.ReportPath' = ''; 'ZeroTrustAssessment.OutputPath' = (Join-Path $TestDrive 'zt-progress') }
            } finally { $env:MT_ZTA_FAKE_PROGRESS = $null }
            $rows.Count | Should -Be 12
            $shown = @($script:Shown -replace "`e\[[0-9;]*m", '')
            $shown | Should -Contain '    Stage 1 of 6 · Exporting Tenant Data'
            $shown | Should -Contain '    13 / 40 · 1 failed · 2 running'
            $shown | Should -Contain '    Error: Export Device failed: Forbidden'
            # Each export that finished is listed with its result and how long it took.
            @($shown | Where-Object { $_ -match '^    \S Device: Forbidden  1\.0 s$' }).Count | Should -Be 1
            @($shown | Where-Object { $_ -match '##maester' }) | Should -BeNullOrEmpty
        }

        It 'signs the child in with the app and certificate Maester uses' {
            function global:Get-MgContext {
                [pscustomobject]@{ TenantId = '22222222-2222-2222-2222-222222222222'; AuthType = 'AppOnly'; ClientId = 'app-id'; CertificateThumbprint = 'ABC123' }
            }
            $null = Invoke-ZtaPack -Setting @{ 'ZeroTrustAssessment.ReportPath' = '' }
            $call = Get-Content -LiteralPath $script:CallLog -Raw | ConvertFrom-Json
            $call.Connect.TenantId | Should -Be '22222222-2222-2222-2222-222222222222'
            $call.Connect.ClientId | Should -Be 'app-id'
            $call.Connect.Certificate | Should -Be 'ABC123'
        }

        It 'signs the child in with the thumbprint of a certificate object Maester was connected with' {
            function global:Get-MgContext {
                [pscustomobject]@{ TenantId = '22222222-2222-2222-2222-222222222222'; AuthType = 'AppOnly'; ClientId = 'app-id'; CertificateThumbprint = $null; Certificate = [pscustomobject]@{ Thumbprint = 'DEF456' } }
            }
            $null = Invoke-ZtaPack -Setting @{ 'ZeroTrustAssessment.ReportPath' = '' }
            (Get-Content -LiteralPath $script:CallLog -Raw | ConvertFrom-Json).Connect.Certificate | Should -Be 'DEF456'
        }

        It 'skips the family, rather than wait for a sign-in, when Maester is connected app-only without a certificate' {
            function global:Get-MgContext {
                [pscustomobject]@{ TenantId = '22222222-2222-2222-2222-222222222222'; AuthType = 'AppOnly'; ClientId = 'app-id'; CertificateThumbprint = $null }
            }
            $rows = Invoke-ZtaPack -Setting @{ 'ZeroTrustAssessment.ReportPath' = '' }
            $rows.Count | Should -Be 1
            $rows[0].Result | Should -Be 'Skipped'
            $rows[0].ReasonDetail | Should -BeLike '*signs in app-only only with a certificate*'
        }

        It 'deletes a temporary output folder after reading it' {
            $before = @(Get-ChildItem -LiteralPath ([System.IO.Path]::GetTempPath()) -Filter 'maester-zta-*' -ErrorAction SilentlyContinue).Count
            $rows = Invoke-ZtaPack -Setting @{ 'ZeroTrustAssessment.ReportPath' = '' }
            $rows.Count | Should -Be 12
            @(Get-ChildItem -LiteralPath ([System.IO.Path]::GetTempPath()) -Filter 'maester-zta-*' -ErrorAction SilentlyContinue).Count | Should -Be $before
        }

        It 'embeds the assessment HTML report before deleting the temporary output folder' {
            if (-not $script:CanAttach) { Set-ItResult -Skipped -Because 'this Maester has no Add-MtReportAttachment' }
            Clear-ZtaAttachment
            $null = Invoke-ZtaPack -Setting @{ 'ZeroTrustAssessment.ReportPath' = '' }
            @(Get-ZtaAttachment).Name | Should -Be 'Zero Trust Assessment'
        }

        It 'skips the family when the module is not installed' {
            # Leave out every module folder that has the assessment, so a copy installed on this machine never
            # runs a real assessment against the tenant it last signed in to.
            $env:PSModulePath = @($script:OriginalModulePath -split [System.IO.Path]::PathSeparator | Where-Object {
                    # A folder this account cannot read (the CI runner's /root) cannot load the module either.
                    $_ -and -not $(try { Test-Path -LiteralPath (Join-Path $_ 'ZeroTrustAssessment') -ErrorAction Stop } catch { $false })
                }) -join [System.IO.Path]::PathSeparator
            try {
                $rows = Invoke-ZtaPack -Setting @{ 'ZeroTrustAssessment.ReportPath' = '' }
            } finally {
                $env:PSModulePath = $script:FakeModules + [System.IO.Path]::PathSeparator + $script:OriginalModulePath
            }
            $rows.Count | Should -Be 1
            $rows[0].Result | Should -Be 'Skipped'
            $rows[0].ReasonDetail | Should -BeLike '*ZeroTrustAssessment module is not installed*'
        }
    }
}
