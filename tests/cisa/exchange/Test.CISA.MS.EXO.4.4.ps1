function Test-MtCisaDmarcReport {
    <#
    .SYNOPSIS
    Checks that the DMARC record of every accepted domain names an agency point of contact for aggregate and failure reports.

    .DESCRIPTION
    An agency point of contact SHOULD be included for aggregate and failure reports.

    For each accepted domain the test reads the DMARC record that applies to it: the domain's own record or,
    when it has none, the record of its organizational domain (as receivers do, RFC 7489 section 6.6.3). The
    organizational domain is found with the public suffix list, so domains such as contoso.co.uk are handled.

    A domain passes when its record has at least one aggregate report (rua) address other than
    reports@dmarc.cyber.dhs.gov and at least one failure report (ruf) address, as in the ScubaGear policy.

    .EXAMPLE
    Test-MtCisaDmarcReport

    Returns true if the DMARC record of every accepted domain includes an agency point of contact for aggregate and failure reports.

    .LINK
    https://maester.dev/docs/commands/Test-MtCisaDmarcReport
    #>
    [MaesterTest(
        Id = 'CISA.MS.EXO.4.4',
        Title = 'An agency point of contact SHOULD be included for aggregate and failure reports.',
        Severity = 'Medium',
        Category = 'CISA',
        Tag = ('MS.EXO', 'MS.EXO.4.4'),
        Service = 'ExchangeOnline',
        Author = 'soulemike',
        Contributor = 'merill'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $cisaAddress = 'reports@dmarc.cyber.dhs.gov'
    $acceptedDomains = Get-MtExo -Request AcceptedDomain | Sort-Object -Property DomainName -Unique

    $rows = foreach ($domain in $acceptedDomains) {
        $domainName = "$($domain.DomainName)".ToLowerInvariant()
        $row = [pscustomobject]@{ Domain = $domainName; RecordDomain = $domainName; Status = 'Failed'; Reason = ''; Aggregate = @(); Failure = @() }

        if ($domain.IsCoexistenceDomain -or $domain.InitialDomain -or $domainName -like '*.onmicrosoft.com') {
            $row.Status = 'Skipped'
            $row.Reason = 'Microsoft-managed domain'
            $row
            continue
        }

        $record = (Get-MailAuthenticationRecord -DomainName $domainName -Records DMARC).dmarcRecord
        # A subdomain without its own record uses its organizational domain's record.
        if ($record -is [string] -and $record -eq 'Record does not exist') {
            $organizationalDomain = Get-MtRegistrableDomain -DomainName $domainName
            if ($organizationalDomain -and $organizationalDomain -ne $domainName) {
                $row.RecordDomain = $organizationalDomain
                $record = (Get-MailAuthenticationRecord -DomainName $organizationalDomain -Records DMARC).dmarcRecord
            }
        }

        # The DMARCRecord class is defined inside a script block, so match the type by name.
        if ($null -ne $record -and $record.GetType().Name -eq 'DMARCRecord') {
            $row.Aggregate = @($record.reportAggregate.mailAddress | Where-Object { $_ } | ForEach-Object { "$($_.Address)".ToLowerInvariant() } | Sort-Object -Unique)
            $row.Failure = @($record.reportForensic.mailAddress | Where-Object { $_ } | ForEach-Object { "$($_.Address)".ToLowerInvariant() } | Sort-Object -Unique)
            $agencyAggregate = @($row.Aggregate | Where-Object { $_ -ne $cisaAddress })
            $missing = @()
            if ($agencyAggregate.Count -eq 0) { $missing += 'aggregate reports (rua)' }
            if ($row.Failure.Count -eq 0) { $missing += 'failure reports (ruf)' }
            if ($missing.Count -eq 0) {
                $row.Status = 'Passed'
            } else {
                $row.Reason = "No agency point of contact for $($missing -join ' or ')"
            }
        } elseif ("$record" -like '*not available') {
            $row.Status = 'Skipped'
            $row.Reason = "$record"
        } elseif ("$record" -eq 'Record does not exist') {
            $row.Reason = 'No DMARC record'
        } else {
            $row.Reason = "$record"
        }
        $row
    }
    $rows = @($rows)

    if (-not ($rows | Where-Object { $_.Status -ne 'Skipped' })) {
        if ($rows | Where-Object { $_.Reason -like '*not available' }) {
            Add-MtTestResultDetail -SkippedBecause NotSupported
        } else {
            Add-MtTestResultDetail -SkippedBecause NotApplicable
        }
        return $null
    }

    $testResult = -not ($rows | Where-Object { $_.Status -eq 'Failed' })

    if ($testResult) {
        $testResultMarkdown = "Well done. The DMARC record of every domain includes an agency point of contact for aggregate and failure reports.`n`n%TestResult%"
    } else {
        $testResultMarkdown = "The DMARC record of one or more domains does not include an agency point of contact for aggregate and failure reports.`n`n%TestResult%"
    }

    $formatAddresses = {
        param([string[]] $Addresses)
        if ($Addresses.Count -eq 0) { return '—' }
        if ($Addresses.Count -gt 3) { return "$($Addresses[0..1] -join ', ') and $($Addresses.Count - 2) more" }
        $Addresses -join ', '
    }
    $result = "| Domain | Record | Result | Aggregate (rua) | Failure (ruf) | Reason |`n"
    $result += "| --- | --- | --- | --- | --- | --- |`n"
    foreach ($row in $rows) {
        $status = switch ($row.Status) { 'Passed' { '✅ Pass' } 'Failed' { '❌ Fail' } default { '⏭️ Skipped' } }
        $recordName = if ($row.Status -eq 'Skipped' -and $row.Reason -eq 'Microsoft-managed domain') { '—' } else { "_dmarc.$($row.RecordDomain)" }
        $result += "| $($row.Domain) | $recordName | $status | $(& $formatAddresses $row.Aggregate) | $(& $formatAddresses $row.Failure) | $($row.Reason) |`n"
    }

    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $result
    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
