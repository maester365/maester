Describe 'Send-MtMail HTML encoding' {
    BeforeEach {
        $results = [PSCustomObject]@{
            TenantName = 'Contoso & Partners'
            TenantId = 'tenant-id'
            CurrentVersion = '2.0.0'
            LatestVersion = '2.0.0'
            TotalCount = 1
            PassedCount = 1
            FailedCount = 0
            InvestigateCount = 0
            SkippedCount = 0
            NotRunCount = 0
            Tests = @([PSCustomObject]@{ Name = 'Example test'; Result = 'Passed' })
        }
        $parameters = @{ MaesterResults = $results; Recipient = 'test@example.com'; CreateBodyOnly = $true }
    }

    It 'Encodes HTML in <_>' -ForEach @(
        'TenantName', 'TenantId', 'CurrentVersion', 'LatestVersion', 'TotalCount',
        'PassedCount', 'FailedCount', 'InvestigateCount', 'SkippedCount', 'NotRunCount'
    ) {
        $Field = $_
        $payload = '<img src=x onerror="alert(1)"> & ''quoted'' $& $$ %TestSummary%'
        $results.$Field = $payload
        $body = (Send-MtMail @parameters).message.body.content
        $body.Contains($payload) | Should -BeFalse
        $body.Contains([System.Net.WebUtility]::HtmlEncode($payload)) | Should -BeTrue
    }

    It 'Encodes test names and result text while preserving status icons' {
        $payload = '</td><script>alert(1)</script> $& $$ %TestResultsLink%'
        $results.Tests[0].Name = $payload
        $results.Tests += [PSCustomObject]@{ Name = 'Unknown status'; Result = $payload }
        $body = (Send-MtMail @parameters).message.body.content
        $body.Contains($payload) | Should -BeFalse
        ([regex]::Matches($body, [regex]::Escape([System.Net.WebUtility]::HtmlEncode($payload)))).Count | Should -Be 2
        $body | Should -BeLike '*pill-pass.png*'
    }

    It 'Encodes the link attribute and preserves query parameters' {
        $uri = "https://example.com/results?a=1&b=' onclick='alert(1)"
        $body = (Send-MtMail @parameters -TestResultsUri $uri).message.body.content
        $encodedUri = [System.Net.WebUtility]::HtmlEncode(([uri]$uri).AbsoluteUri)
        $body.Contains("href='$encodedUri'") | Should -BeTrue
        $body.Contains("' onclick='") | Should -BeFalse
    }

    It 'Rejects unsafe or relative links: <_>' -ForEach @(
        'javascript:alert(1)', 'data:text/html,<script>alert(1)</script>',
        'file:///tmp/report.html', '//example.com/report', '/report.html'
    ) {
        { Send-MtMail @parameters -TestResultsUri $_ } | Should -Throw '*absolute HTTP or HTTPS*'
    }

    It 'Preserves ordinary content and missing-count fallbacks' {
        $results.NotRunCount = $null
        $results.SkippedCount = $null
        $results.InvestigateCount = $null
        $body = (Send-MtMail @parameters -TestResultsUri 'http://example.com/report').message.body.content
        $body | Should -BeLike '*Contoso &amp; Partners*'
        $body | Should -BeLike '*Example test*'
        $body | Should -BeLike '*Investigate: -*Skipped: -*Not Run: -*'
        $body | Should -BeLike "*href='http://example.com/report'*"
    }
}
