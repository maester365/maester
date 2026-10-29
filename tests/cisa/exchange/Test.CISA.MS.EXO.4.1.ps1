function Test-MtCisaDmarcRecordExist {
    <#
    .SYNOPSIS
    Checks that a DMARC record applies to every accepted domain

    .DESCRIPTION
    A DMARC policy SHALL be published for every second-level domain.

    Applies the rule of CISA ScubaGear (MS.EXO.4.1v1): every accepted domain except the coexistence domain
    needs a DMARC record that starts with v=DMARC1;. The record can be published at the domain or at a parent
    domain found by the DNS tree walk of RFC 9989. The policy and the report addresses are checked by
    MS.EXO.4.2 and MS.EXO.4.3.

    .EXAMPLE
    Test-MtCisaDmarcRecordExist

    Returns true if a DMARC record applies to every accepted domain

    .LINK
    https://maester.dev/docs/commands/Test-MtCisaDmarcRecordExist
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'Strict', Justification = 'Kept so that configurations that set it still run')]
    [MaesterTest(
        Id = 'CISA.MS.EXO.4.1',
        Title = 'A DMARC policy SHALL be published for every second-level domain.',
        Product = 'exchange',
        Feature = 'email-authentication',
        Area = 'email-protection',
        ResourceType = 'Domain',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = ('T1566', 'T1598', 'T1684.002'),
        Control = 'cisa-scuba:MS.EXO.4.1',
        Service = 'ExchangeOnline',
        Author = 'soulemike',
        Contributor = 'moorereason'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # No longer used: every accepted domain is checked. Kept so that configurations that set it still run.
        [switch]$Strict
    )

    # The coexistence domain (contoso.mail.onmicrosoft.com) is managed by Microsoft and cannot have a DMARC record.
    $domains = @(Get-MtExo -Request AcceptedDomain | Where-Object { -not $_.IsCoexistenceDomain } | Sort-Object -Property DomainName -Unique)

    $dnsCache = @{}
    $dmarcRecords = [System.Collections.Generic.List[object]]::new()
    foreach ($domain in $domains) {
        $dmarcRecord = Find-MtDmarcRecord -DomainName $domain.DomainName -Cache $dnsCache
        $notAvailable = @($dmarcRecord.Lookups | Where-Object { $_.Status -eq 'NotAvailable' })
        if ($notAvailable) {
            Write-Verbose $notAvailable[0].Error
            Add-MtTestResultDetail -SkippedBecause NotSupported
            return $null
        }
        $dmarcRecords.Add($dmarcRecord)
    }

    $testResult = $true
    $result = "| Domain | Result | Found at | Details |`n"
    $result += "| --- | --- | --- | --- |`n"
    foreach ($item in $dmarcRecords) {
        $passed = $false
        $foundAt = if ($item.PolicyDomain) { Get-MtSafeMarkdown "_dmarc.$($item.PolicyDomain)" }
        if ($null -eq $item.Record) {
            $failedLookup = $item.Lookups | Where-Object { $_.Status -eq 'Error' } | Select-Object -First 1
            $ambiguousLookup = $item.Lookups | Where-Object { @($_.Answers -match '^v=DMARC1').Count -gt 1 } | Select-Object -First 1
            $details = 'No DMARC record found.'
            if ($failedLookup) {
                $details += " The DNS lookup for $(Get-MtSafeMarkdown $failedLookup.Name) failed: $(Get-MtSafeMarkdown $failedLookup.Error)"
            } elseif ($ambiguousLookup) {
                $details += " $(Get-MtSafeMarkdown $ambiguousLookup.Name) has more than one DMARC record."
            }
        } elseif (-not $item.Record.StartsWith('v=DMARC1;', [System.StringComparison]::Ordinal)) {
            $details = "The record does not start with v=DMARC1;: $(Get-MtSafeMarkdown $item.Record)"
        } else {
            $passed = $true
            $details = Get-MtSafeMarkdown $item.Record
        }
        if (-not $passed) {
            $testResult = $false
        }
        $itemResult = if ($passed) { "✅ Pass" } else { "❌ Fail" }
        $result += "| $(Get-MtSafeMarkdown $item.DomainName) | $itemResult | $foundAt | $details |`n"
    }

    if ($testResult) {
        $testResultMarkdown = "Well done. A DMARC record applies to every accepted domain.`n`n%TestResult%"
    } else {
        $testResultMarkdown = "Some accepted domains do not have a DMARC record.`n`n%TestResult%"
    }
    # String.Replace, as a record can contain '$', which -replace reads as a substitution.
    $testResultMarkdown = $testResultMarkdown.Replace('%TestResult%', $result)

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
