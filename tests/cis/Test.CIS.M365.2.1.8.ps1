function Test-MtCisSpfRecordsPublished {
    <#
    .SYNOPSIS
        Checks that every custom accepted domain publishes an SPF record that ends in -all or ~all.

    .DESCRIPTION
        Looks up the SPF record of each custom accepted domain and passes when a record exists and ends with a hard fail or soft fail, either directly or through a redirect. Domains in the onmicrosoft.com namespace are excluded because Microsoft manages their SPF.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (2.1.8, L1)

    .EXAMPLE
        Test-MtCisSpfRecordsPublished

        Returns true if all custom domains publish an SPF record that ends in -all or ~all.

    .LINK
        https://maester.dev/docs/tests/CIS.M365.2.1.8
    #>
    [MaesterTest(
        Id = 'CIS.M365.2.1.8',
        Title = 'Ensure that SPF records are published for all Exchange Domains',
        Product = 'defender',
        Feature = 'email-authentication',
        Area = 'email-protection',
        ResourceType = 'Domain',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Medium',
        Mitre = ('T1566', 'T1684.002'),
        Control = ('cis-m365:2.1.8', 'nist-800-53-r5:SI-8'),
        Service = 'ExchangeOnline',
        Author = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Getting accepted domains...'
    $domains = @(Get-MtExo -Request AcceptedDomain | Where-Object { $_.InitialDomain -eq $false -and $_.IsCoExistenceDomain -eq $false })

    $report = foreach ($domain in $domains) {
        $name = $domain.DomainName
        $spf = ConvertFrom-MailAuthenticationRecordSpf -DomainName $name
        if ($spf -is [string] -and ($spf -like '*not available' -or $spf -eq 'DNS lookup unavailable')) {
            [pscustomobject]@{ Domain = $name; Record = $null; Pass = $null; Detail = 'DNS lookup not available' }
            continue
        }
        $record = if ($spf.GetType().Name -eq 'SPFRecord') { $spf.record } else { $null }
        $effective = $record
        $detail = ''
        # RFC 7208 section 5.1: a redirect is ignored when the record has an all mechanism.
        $localAll = [regex]::Match([string]$record, '(^|\s)(?<q>[+?~-]?)all(\s|$)')
        if (-not $localAll.Success -and $record -match 'redirect=(?<target>\S+)') {
            $target = $Matches['target']
            $redirected = ConvertFrom-MailAuthenticationRecordSpf -DomainName $target
            if ($redirected -is [string] -and ($redirected -like '*not available' -or $redirected -eq 'DNS lookup unavailable')) {
                [pscustomobject]@{ Domain = $name; Record = $record; Pass = $null; Detail = "DNS lookup not available for $target" }
                continue
            }
            $effective = if ($redirected.GetType().Name -eq 'SPFRecord') { $redirected.record } else { $null }
            $detail = "Redirects to $target"
        }
        $effectiveAll = [regex]::Match([string]$effective, '(^|\s)(?<q>[+?~-]?)all(\s|$)')
        $pass = $effectiveAll.Success -and $effectiveAll.Groups['q'].Value -in '-', '~'
        if (-not $record) {
            $detail = 'No SPF record found'
        } elseif (-not $pass) {
            $detail = 'The record does not end with -all or ~all'
        }
        [pscustomobject]@{ Domain = $name; Record = $record; Pass = $pass; Detail = $detail }
    }
    $checked = @($report | Where-Object { $null -ne $_.Pass })
    if ($domains.Count -gt 0 -and $checked.Count -eq 0) {
        Add-MtTestResultDetail -SkippedBecause NotSupported
        return $null
    }
    $failed = @($checked | Where-Object { -not $_.Pass })
    $testResult = $failed.Count -eq 0

    $passText = if ($domains.Count -eq 0) { 'There are no custom domains, so no SPF records are required.' } else { 'All custom domains publish an SPF record that ends in -all or ~all.' }
    $failText = "$($failed.Count) custom domain(s) do not publish a compliant SPF record."

    $resultMd = "| Domain | SPF record | Detail | Result |`n"
    $resultMd += "| --- | --- | --- | --- |`n"
    foreach ($row in $report) {
        $resultMd += "| $($row.Domain) | $($row.Record) | $($row.Detail) | $(if ($null -eq $row.Pass) { 'Not checked' } elseif ($row.Pass) { '✅ Pass' } else { '❌ Fail' }) |`n"
    }

    if ($testResult) {
        $testResultMarkdown = "Well done. $passText`n`n%TestResult%"
    } else {
        $testResultMarkdown = "$failText`n`n%TestResult%"
    }
    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $resultMd

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
