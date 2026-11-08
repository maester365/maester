Describe 'Get-MtHtmlReport' {
    BeforeAll {
        # Reads the results Get-MtHtmlReport embeds: gzip-compressed, Base64-encoded JSON in the data element.
        function Get-ReportDataText([string] $Html) {
            $match = [regex]::Match($Html, '<script type="application/octet-stream" id="maester-report-data" data-encoding="gzip\+base64">([A-Za-z0-9+/=]*)</script>')
            if (-not $match.Success) { throw 'The report has no compressed maester-report-data element.' }
            $stream = [System.IO.MemoryStream]::new([System.Convert]::FromBase64String($match.Groups[1].Value))
            $reader = [System.IO.StreamReader]::new([System.IO.Compression.GZipStream]::new($stream, [System.IO.Compression.CompressionMode]::Decompress))
            try { $reader.ReadToEnd() } finally { $reader.Dispose() }
        }

        # The function resolves the template relative to its own location (powershell/public/report/)
        # From the test directory (powershell/tests/functions/) the template is at ../../assets/
        $templatePath = Join-Path -Path $PSScriptRoot -ChildPath '../../assets/ReportTemplate.html'
        $templateAvailable = Test-Path $templatePath

        $singleTenant = [PSCustomObject]@{
            TenantId       = 'single-tenant-id'
            TenantName     = 'Single Tenant'
            Result         = 'Passed'
            TotalCount     = 5
            PassedCount    = 4
            FailedCount    = 1
            ErrorCount     = 0
            SkippedCount   = 0
            InvestigateCount = 0
            NotRunCount    = 0
            ExecutedAt     = '2026-03-30T10:00:00'
            TotalDuration  = '00:01:00'
            UserDuration   = '00:00:50'
            DiscoveryDuration = '00:00:08'
            FrameworkDuration = '00:00:01'
            CurrentVersion = '2.0.0'
            LatestVersion  = '2.0.0'
            Account        = 'test@contoso.com'
            SystemInfo     = [PSCustomObject]@{ MachineName = 'TEST-01' }
            PowerShellInfo = [PSCustomObject]@{ Version = '7.4.1' }
            LoadedModules  = @()
            InvokeCommand  = 'Invoke-Maester'
            MgContext      = [PSCustomObject]@{ TenantId = 'single-tenant-id' }
            MaesterConfig  = [PSCustomObject]@{
                GlobalSettings = [PSCustomObject]@{
                    EmergencyAccessAccounts = @(
                        [PSCustomObject]@{
                            Type              = 'User'
                            UserPrincipalName = 'BreakGlass1@contoso.com'
                        }
                    )
                }
                TestSettings   = @()
            }
            Tests          = @(
                [PSCustomObject]@{
                    Index = 1; Id = 'MT.1033.0'; Title = 'User should be blocked from using legacy authentication (user@contoso.com)'
                    Name = 'MT.1033.0: User should be blocked from using legacy authentication (user@contoso.com)'; Result = 'Passed'
                    Severity = 'High'; Tag = @('MT.1033'); Block = 'Maester'
                    Duration = '00:00:01'; ErrorRecord = @()
                    ResultDetail = [PSCustomObject]@{ TestDescription = 'Desc'; TestResult = 'user@contoso.com (11111111-1111-1111-1111-111111111111)' }
                }
            )
            AffectedObjects = @(
                [PSCustomObject]@{
                    System = 'EntraID'; AnchorKind = 'Instance'; Type = 'User'
                    Id = '11111111-1111-1111-1111-111111111111'; UniqueId = 'object-user-001'
                    DisplayName = 'user@contoso.com'; PortalLink = 'https://example.test/11111111-1111-1111-1111-111111111111'
                    Tests = @('MT.1033.0'); Sources = @('GraphObjects')
                }
            )
            Blocks         = @(
                [PSCustomObject]@{ Name = 'Maester'; PassedCount = 4; FailedCount = 1; TotalCount = 5 }
            )
            EndOfJson      = 'EndOfJson'
        }

        $tenant1 = [PSCustomObject]@{
            TenantId       = 'tenant-1-id'
            TenantName     = 'Tenant One'
            Result         = 'Passed'
            TotalCount     = 3
            PassedCount    = 3
            FailedCount    = 0
            ErrorCount     = 0
            SkippedCount   = 0
            InvestigateCount = 0
            NotRunCount    = 0
            ExecutedAt     = '2026-03-30T10:00:00'
            CurrentVersion = '2.0.0'
            LatestVersion  = '2.0.0'
            Tests          = @(
                [PSCustomObject]@{ Index = 1; Id = 'MT.1001'; Result = 'Passed'; Block = 'Maester' }
            )
            Blocks         = @(
                [PSCustomObject]@{ Name = 'Maester'; PassedCount = 3; TotalCount = 3 }
            )
            EndOfJson      = 'EndOfJson'
        }

        $tenant2 = [PSCustomObject]@{
            TenantId       = 'tenant-2-id'
            TenantName     = 'Tenant Two'
            Result         = 'Failed'
            TotalCount     = 5
            PassedCount    = 3
            FailedCount    = 2
            ErrorCount     = 0
            SkippedCount   = 0
            InvestigateCount = 0
            NotRunCount    = 0
            ExecutedAt     = '2026-03-30T11:00:00'
            CurrentVersion = '2.0.0'
            LatestVersion  = '2.0.0'
            Tests          = @(
                [PSCustomObject]@{ Index = 1; Id = 'MT.1001'; Result = 'Failed'; Block = 'Maester' }
            )
            Blocks         = @(
                [PSCustomObject]@{ Name = 'Maester'; PassedCount = 3; FailedCount = 2; TotalCount = 5 }
            )
            EndOfJson      = 'EndOfJson'
        }
    }

    Context 'Single-tenant report' {
        BeforeEach {
            if (-not $templateAvailable) {
                Set-ItResult -Skipped -Because 'ReportTemplate.html not found'
            }
        }

        It 'Should generate valid HTML' {
            $html = Get-MtHtmlReport -MaesterResults $singleTenant

            $html | Should -Not -BeNullOrEmpty
            $html | Should -BeLike '*<!DOCTYPE html>*'
            $html | Should -BeLike '*</html>*'
        }

        It 'Should contain the tenant name in the output' {
            $html = Get-MtHtmlReport -MaesterResults $singleTenant

            (Get-ReportDataText $html) | Should -BeLike '*Single Tenant*'
        }

        It 'Should contain the test data' {
            $html = Get-MtHtmlReport -MaesterResults $singleTenant

            (Get-ReportDataText $html) | Should -BeLike '*MT.1033.0*'
        }

        It 'Should embed the facts of an object, and no Facts property for objects without any' {
            $html = Get-MtHtmlReport -MaesterResults $singleTenant
            (Get-ReportDataText $html) | Should -Not -BeLike '*"Facts"*'

            $record = $singleTenant.AffectedObjects[0] | Select-Object -Property *
            $record | Add-Member -NotePropertyName Facts -NotePropertyValue @(
                [PSCustomObject]@{ Name = 'MFA'; Value = 'Not registered'; Tone = 'Risk'; Key = 'user.mfaRegistered'; Raw = $false; Source = 'Zero Trust Assessment'; AsOf = '2026-10-23T12:30:00Z' }
            )
            $withFacts = $singleTenant | Select-Object -Property * -ExcludeProperty AffectedObjects
            $withFacts | Add-Member -NotePropertyName AffectedObjects -NotePropertyValue @($record)
            $html = Get-MtHtmlReport -MaesterResults $withFacts

            (Get-ReportDataText $html) | Should -BeLike '*"Facts"*'
            (Get-ReportDataText $html) | Should -BeLike '*Not registered*'
            (Get-ReportDataText $html) | Should -BeLike '*"Key":"user.mfaRegistered","Raw":false*'
        }

        It 'Should contain emergency access account config data' {
            $html = Get-MtHtmlReport -MaesterResults $singleTenant

            (Get-ReportDataText $html) | Should -BeLike '*BreakGlass1@contoso.com*'
        }

        It 'Should keep user PII when RedactUserIdentity is None' {
            $html = Get-MtHtmlReport -MaesterResults $singleTenant -RedactUserIdentity None

            (Get-ReportDataText $html) | Should -BeLike '*user@contoso.com*'
        }

        It 'Should default to keeping user PII' {
            $html = Get-MtHtmlReport -MaesterResults $singleTenant

            (Get-ReportDataText $html) | Should -BeLike '*user@contoso.com*'
        }

        It 'Should replace user PII with the object unique ID for <_>' -ForEach @('AllOutputs', 'HtmlOnly') {
            $html = Get-MtHtmlReport -MaesterResults $singleTenant -RedactUserIdentity $_

            (Get-ReportDataText $html) | Should -BeLike '*object-user-001*'
            (Get-ReportDataText $html) | Should -Not -BeLike '*user@contoso.com*'
            (Get-ReportDataText $html) | Should -Not -BeLike '*11111111-1111-1111-1111-111111111111*'
        }

        It 'Should redact the signed-in account for <_>' -ForEach @('AllOutputs', 'HtmlOnly') {
            $html = Get-MtHtmlReport -MaesterResults $singleTenant -RedactUserIdentity $_

            (Get-ReportDataText $html) | Should -Not -BeLike '*test@contoso.com*'
        }

        It 'Should reject an unknown RedactUserIdentity value' {
            { Get-MtHtmlReport -MaesterResults $singleTenant -RedactUserIdentity 'Always' } |
                Should -Throw
        }

        It 'Should redact with a supplied replacement map when the results carry no inventory' {
            $withoutInventory = $singleTenant | Select-Object -Property * -ExcludeProperty AffectedObjects
            $map = @{ 'user@contoso.com' = 'object-user-001'; '11111111-1111-1111-1111-111111111111' = 'object-user-001' }

            $html = Get-MtHtmlReport -MaesterResults $withoutInventory -RedactUserIdentity HtmlOnly -UserIdentityReplacementMap $map

            (Get-ReportDataText $html) | Should -BeLike '*object-user-001*'
            (Get-ReportDataText $html) | Should -Not -BeLike '*user@contoso.com*'
        }

        It 'Should redact a display name that holds an ampersand and angle brackets' {
            $results = $singleTenant | Select-Object -Property * -ExcludeProperty AffectedObjects
            $results.Tests = @($singleTenant.Tests | Select-Object -Property * -ExcludeProperty ResultDetail |
                    Select-Object *, @{ n = 'ResultDetail'; e = { [PSCustomObject]@{ TestResult = 'Owner: R&D <Lab> Admin' } } })

            $html = Get-MtHtmlReport -MaesterResults $results -RedactUserIdentity HtmlOnly -UserIdentityReplacementMap @{ 'R&D <Lab> Admin' = 'object-user-002' }

            (Get-ReportDataText $html) | Should -BeLike '*Owner: object-user-002*'
            (Get-ReportDataText $html) | Should -Not -BeLike '*R\u0026D*'
        }

        It 'Should warn when redaction is requested but the results carry no inventory' {
            $withoutInventory = $singleTenant | Select-Object -Property * -ExcludeProperty AffectedObjects

            $null = Get-MtHtmlReport -MaesterResults $withoutInventory -RedactUserIdentity AllOutputs -WarningVariable warnings -WarningAction SilentlyContinue

            ($warnings -join ' ') | Should -BeLike '*no AffectedObjects*'
        }

        It 'Should not contain sample data from the template' {
            $html = Get-MtHtmlReport -MaesterResults $singleTenant

            $html | Should -Not -BeLike '*Pora Inc*'
        }

        It 'Should not embed a raw script injection payload' {
            $payload = "</script><script>alert('XSS')</script>"
            $maliciousResults = [PSCustomObject]@{
                TenantName = $payload
                EndOfJson  = 'EndOfJson'
            }

            $html = Get-MtHtmlReport -MaesterResults $maliciousResults

            $html | Should -Not -BeLike "*$payload*"
        }
    }

    Context 'Embedded JSON safety' {
        BeforeEach {
            if (-not $templateAvailable) {
                Set-ItResult -Skipped -Because 'ReportTemplate.html not found'
            }
        }

        It 'Preserves hostile values without introducing script markup (multi-tenant: <_>)' -ForEach @($false, $true) {
            $payload = "</script><script>alert('XSS')</script><!--<script> & > " + '\u003c \\ path\file' + [char]0x2028
            $results = [ordered]@{ TenantName = $payload }
            if ($_) {
                $results.Tenants = @(@{ Tests = @(@{ ResultDetail = @{ TestResult = $payload } }) })
            }
            $results.EndOfJson = 'EndOfJson'

            $html = Get-MtHtmlReport -MaesterResults ([PSCustomObject]$results)
            $html | Should -Not -BeLike '*alert(*'
            $decoded = Get-ReportDataText $html | ConvertFrom-Json
            $decoded.TenantName | Should -BeExactly $payload
            if ($_) {
                $decoded.Tenants[0].Tests[0].ResultDetail.TestResult | Should -BeExactly $payload
            }
            $template = Get-Content $templatePath -Raw
            ([regex]::Matches($html, '</script', 'IgnoreCase')).Count |
                Should -Be ([regex]::Matches($template, '</script', 'IgnoreCase')).Count
        }
    }

    Context 'ErrorRecord is left out of the report' {
        BeforeAll {
            # Reads the embedded results back out of the HTML, the reverse of how Get-MtHtmlReport inserts them.
            function Get-EmbeddedResult([string] $Html) {
                Get-ReportDataText $Html | ConvertFrom-Json
            }

            function Get-SampleResultWithErrorRecord([string] $TenantName) {
                [PSCustomObject]@{
                    TenantName = $TenantName
                    Tests      = @(
                        [PSCustomObject]@{
                            Id           = 'MT.1001'
                            Result       = 'Failed'
                            ScriptBlock  = 'Test-MtExample | Should -Be $true'
                            ErrorRecord  = @([PSCustomObject]@{ ScriptStackTrace = 'at <ScriptBlock>, /Users/someone/maester-tests/Example.Tests.ps1: line 1' })
                            ResultDetail = [PSCustomObject]@{ TestResult = 'Example result' }
                        }
                    )
                    EndOfJson  = 'EndOfJson'
                }
            }
        }

        BeforeEach {
            if (-not $templateAvailable) {
                Set-ItResult -Skipped -Because 'ReportTemplate.html not found'
            }
        }

        It 'Omits ErrorRecord and keeps the other test fields (single-tenant)' {
            $results = Get-SampleResultWithErrorRecord -TenantName 'Single Tenant'

            $html = Get-MtHtmlReport -MaesterResults $results
            $embedded = Get-EmbeddedResult $html

            (Get-ReportDataText $html) | Should -Not -BeLike '*/Users/someone/*'
            # A single test must still serialize as an array for the report.
            , $embedded.Tests | Should -BeOfType [array]
            $embedded.Tests[0].PSObject.Properties.Name | Should -Not -Contain 'ErrorRecord'
            $embedded.Tests[0].ScriptBlock | Should -BeExactly 'Test-MtExample | Should -Be $true'
            $embedded.Tests[0].ResultDetail.TestResult | Should -BeExactly 'Example result'
        }

        It 'Omits ErrorRecord from every tenant (multi-tenant)' {
            $merged = Merge-MtMaesterResult -MaesterResults @(
                (Get-SampleResultWithErrorRecord -TenantName 'Tenant One'),
                (Get-SampleResultWithErrorRecord -TenantName 'Tenant Two')
            )

            $html = Get-MtHtmlReport -MaesterResults $merged
            $embedded = Get-EmbeddedResult $html

            (Get-ReportDataText $html) | Should -Not -BeLike '*/Users/someone/*'
            $embedded.Tenants.TenantName | Should -Be @('Tenant One', 'Tenant Two')
            foreach ($tenant in $embedded.Tenants) {
                $tenant.Tests[0].PSObject.Properties.Name | Should -Not -Contain 'ErrorRecord'
                $tenant.Tests[0].ResultDetail.TestResult | Should -BeExactly 'Example result'
            }
        }

        It 'Omits ErrorRecord from multi-tenant results passed as a hashtable' {
            # Ordered so EndOfJson stays last; a plain hashtable's key order changes between processes.
            $results = [ordered]@{
                Tenants   = @(
                    @{
                        TenantName = 'Tenant One'
                        Tests      = @(
                            @{
                                Id           = 'MT.1001'
                                ErrorRecord  = @(@{ ScriptStackTrace = 'at <ScriptBlock>, /Users/someone/maester-tests/Example.Tests.ps1: line 1' })
                                ResultDetail = @{ TestResult = 'Example result' }
                            }
                        )
                    }
                )
                EndOfJson = 'EndOfJson'
            }

            $html = Get-MtHtmlReport -MaesterResults $results
            $embedded = Get-EmbeddedResult $html

            (Get-ReportDataText $html) | Should -Not -BeLike '*/Users/someone/*'
            $embedded.Tenants[0].Tests[0].PSObject.Properties.Name | Should -Not -Contain 'ErrorRecord'
            $embedded.Tenants[0].Tests[0].ResultDetail.TestResult | Should -BeExactly 'Example result'
        }

        It 'Leaves the MaesterResults passed in unchanged' {
            $results = Get-SampleResultWithErrorRecord -TenantName 'Single Tenant'
            $merged = Merge-MtMaesterResult -MaesterResults @((Get-SampleResultWithErrorRecord -TenantName 'Tenant One'))

            $null = Get-MtHtmlReport -MaesterResults $results
            $null = Get-MtHtmlReport -MaesterResults $merged

            $results.Tests[0].ErrorRecord | Should -Not -BeNullOrEmpty
            $merged.Tenants[0].Tests[0].ErrorRecord | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Report attachments' {
        BeforeAll {
            $attachment = [PSCustomObject]@{
                Id = '0123456789abcdef0123456789abcdef'; Name = 'Zero Trust Assessment report'; TestId = 'ZTA'
                ContentType = 'text/html'; FileName = 'ZeroTrustAssessmentReport.html'; Size = 16; Encoding = 'gzip+base64'
                Content = 'H4sIAAAAAAACA7PJKMnNsasqSbTRB7MAq6YLFhAAAAA='
            }
            function Get-ResultWithAttachment([string] $TenantName = 'Single Tenant') {
                [PSCustomObject]@{
                    TenantName  = $TenantName
                    Tests       = @([PSCustomObject]@{ Id = 'ZTA.21770'; ParentId = 'ZTA'; Result = 'Passed' })
                    Attachments = @($attachment)
                    EndOfJson   = 'EndOfJson'
                }
            }
        }

        BeforeEach {
            if (-not $templateAvailable) {
                Set-ItResult -Skipped -Because 'ReportTemplate.html not found'
            }
        }

        It 'Writes each attachment into its own element and lists it without its content' {
            $html = Get-MtHtmlReport -MaesterResults (Get-ResultWithAttachment)

            $html | Should -BeLike ('*<script type="application/octet-stream" id="maester-attachment-{0}" data-encoding="gzip+base64">{1}</script>*' -f $attachment.Id, $attachment.Content)
            $html.IndexOf("maester-attachment-$($attachment.Id)") | Should -BeLessThan $html.LastIndexOf('</body>')
            $json = Get-ReportDataText $html | ConvertFrom-Json
            $json.Attachments[0].Name | Should -Be 'Zero Trust Assessment report'
            $json.Attachments[0].TestId | Should -Be 'ZTA'
            $json.Attachments[0].PSObject.Properties.Name | Should -Not -Contain 'Content'
        }

        It 'Writes the attachments of every tenant' {
            $merged = Merge-MtMaesterResult -MaesterResults @((Get-ResultWithAttachment 'Tenant One'), $tenant2)

            $html = Get-MtHtmlReport -MaesterResults $merged

            ([regex]::Matches($html, 'id="maester-attachment-')).Count | Should -Be 1
        }

        It 'Leaves attachments out and warns when user identities are redacted (<_>)' -ForEach @('HtmlOnly', 'AllOutputs') {
            $html = Get-MtHtmlReport -MaesterResults (Get-ResultWithAttachment) -RedactUserIdentity $_ -UserIdentityReplacementMap @{} -WarningVariable warnings -WarningAction SilentlyContinue

            $html | Should -Not -BeLike '*id="maester-attachment-*'
            (Get-ReportDataText $html) | Should -Not -BeLike '*"Attachments"*'
            $warnings | Should -Not -BeNullOrEmpty
        }

        It 'Keeps a JSON attachment and redacts it like the results (<_>)' -ForEach @('HtmlOnly', 'AllOutputs') {
            $data = '{"Pillars":[{"Note":"Owner jane@contoso.com, Jane Doe"}]}'
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($data)
            $buffer = [System.IO.MemoryStream]::new()
            $gzip = [System.IO.Compression.GZipStream]::new($buffer, [System.IO.Compression.CompressionMode]::Compress, $true)
            $gzip.Write($bytes, 0, $bytes.Length); $gzip.Dispose()
            $jsonAttachment = [PSCustomObject]@{
                Id = 'fedcba9876543210fedcba9876543210'; Name = 'zero-trust-workshop'; TestId = 'ZTA'
                ContentType = 'application/json'; FileName = $null; Size = $bytes.Length; Encoding = 'gzip+base64'
                Content = [System.Convert]::ToBase64String($buffer.ToArray())
            }
            $results = Get-ResultWithAttachment
            $results.Attachments = @($attachment, $jsonAttachment)
            $map = @{ 'jane@contoso.com' = 'user-001'; 'Jane Doe' = 'user-001' }

            $html = Get-MtHtmlReport -MaesterResults $results -RedactUserIdentity $_ -UserIdentityReplacementMap $map -WarningVariable warnings -WarningAction SilentlyContinue

            $html | Should -Not -BeLike "*id=`"maester-attachment-$($attachment.Id)`"*"
            $embedded = [regex]::Match($html, "id=`"maester-attachment-$($jsonAttachment.Id)`" data-encoding=`"gzip\+base64`">([A-Za-z0-9+/=]+)<").Groups[1].Value
            $embedded | Should -Not -BeNullOrEmpty
            $stream = [System.IO.MemoryStream]::new([System.Convert]::FromBase64String($embedded))
            $reader = [System.IO.StreamReader]::new([System.IO.Compression.GZipStream]::new($stream, [System.IO.Compression.CompressionMode]::Decompress))
            $text = $reader.ReadToEnd(); $reader.Dispose()
            $text | Should -Be '{"Pillars":[{"Note":"Owner user-001, user-001"}]}'
            $json = Get-ReportDataText $html | ConvertFrom-Json
            @($json.Attachments).Name | Should -Be @('zero-trust-workshop')
            $warnings | Should -Not -BeNullOrEmpty
            $jsonAttachment.Content | Should -Be ([System.Convert]::ToBase64String($buffer.ToArray()))
        }

        It 'Leaves the MaesterResults passed in unchanged' {
            $results = Get-ResultWithAttachment

            $null = Get-MtHtmlReport -MaesterResults $results

            $results.Attachments[0].Content | Should -Be $attachment.Content
        }
    }

    Context 'Multi-tenant report' {
        BeforeAll {
            $merged = Merge-MtMaesterResult -MaesterResults @($tenant1, $tenant2)
        }

        BeforeEach {
            if (-not $templateAvailable) {
                Set-ItResult -Skipped -Because 'ReportTemplate.html not found'
            }
        }

        It 'Should generate valid HTML' {
            $html = Get-MtHtmlReport -MaesterResults $merged

            $html | Should -Not -BeNullOrEmpty
            $html | Should -BeLike '*<!DOCTYPE html>*'
            $html | Should -BeLike '*</html>*'
        }

        It 'Should contain both tenant names' {
            $html = Get-MtHtmlReport -MaesterResults $merged

            (Get-ReportDataText $html) | Should -BeLike '*Tenant One*'
            (Get-ReportDataText $html) | Should -BeLike '*Tenant Two*'
        }

        It 'Should not contain sample data from the template' {
            $html = Get-MtHtmlReport -MaesterResults $merged

            $html | Should -Not -BeLike '*Pora Inc*'
        }

        It 'Should contain the Tenants key in the output' {
            $html = Get-MtHtmlReport -MaesterResults $merged

            (Get-ReportDataText $html) | Should -BeLike '*Tenants*'
        }

        It 'Embeds the results compressed, in one data element' {
            $html = Get-MtHtmlReport -MaesterResults $merged

            ([regex]::Matches($html, 'id="maester-report-data"')).Count | Should -Be 1
            $html | Should -Not -BeLike '*"Tenant One"*'
            $html | Should -Not -BeLike '*EndOfJson*'
            (Get-ReportDataText $html) | Should -BeLike '*"Tenant One"*'
        }
    }
}
