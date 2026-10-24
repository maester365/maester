function Test-MtCisDmarcRecordsPublished {
    <#
    .SYNOPSIS
        Checks that every accepted domain has a DMARC policy of quarantine or reject with aggregate and forensic reporting.

    .DESCRIPTION
        Looks up the DMARC record that applies to each accepted domain, falling back to the organisational domain, and passes when the applied policy is quarantine or reject, covers 100 percent of mail and defines mailto addresses for aggregate (rua) and forensic (ruf) reports.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (2.1.10, L1)

    .EXAMPLE
        Test-MtCisDmarcRecordsPublished

        Returns true if all accepted domains have an enforcing DMARC policy with reporting addresses.

    .LINK
        https://maester.dev/docs/tests/CIS.M365.2.1.10
    #>
    [MaesterTest(
        Id = 'CIS.M365.2.1.10',
        Title = 'Ensure DMARC records for all Exchange Online domains are published',
        Product = 'defender',
        Feature = 'email-authentication',
        Area = 'email-protection',
        ResourceType = 'Domain',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Medium',
        Mitre = ('T1566', 'T1684.002'),
        Control = ('cis-m365:2.1.10', 'nist-800-53-r5:SI-8'),
        Service = 'ExchangeOnline',
        Author = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Getting accepted domains...'
    $domains = @(Get-MtExo -Request AcceptedDomain | Where-Object { $_.IsCoExistenceDomain -eq $false })

    $report = foreach ($domain in $domains) {
        $name = $domain.DomainName
        $dmarc = $null
        $source = $null
        $unavailable = $false
        # DMARC policy discovery uses the domain, then its organisational domain only.
        $candidates = @($name, (Get-MtRegistrableDomain -DomainName $name)) | Select-Object -Unique
        foreach ($candidate in $candidates) {
            $found = ConvertFrom-MailAuthenticationRecordDmarc -DomainName $candidate
            if ($found -is [string] -and ($found -like '*not available' -or $found -eq 'DNS lookup unavailable')) { $unavailable = $true; break }
            if ($found.GetType().Name -eq 'DMARCRecord') {
                $dmarc = $found
                $source = $candidate
                break
            }
        }
        if ($unavailable) {
            [pscustomobject]@{ Domain = $name; Policy = 'Not checked'; Source = 'None'; Failed = 'DNS lookup not available'; Pass = $null }
            continue
        }
        $policy = $null
        if ($dmarc) {
            $policy = if ($source -ne $name -and $dmarc.policySubdomain) { $dmarc.policySubdomain } else { $dmarc.policy }
        }
        $checks = [ordered]@{
            'Record is valid' = $null -eq $dmarc -or $dmarc.valid
            'Policy is quarantine or reject' = $policy -in @('quarantine', 'reject')
            'Applies to 100 percent' = $null -eq $dmarc -or $dmarc.percentage -eq 100 -or $null -eq $dmarc.percentage
            'Aggregate reports (rua)' = @($dmarc.reportAggregate | Where-Object { $_.mailAddress }).Count -gt 0
            'Forensic reports (ruf)' = @($dmarc.reportForensic | Where-Object { $_.mailAddress }).Count -gt 0
        }
        $failedChecks = @($checks.GetEnumerator() | Where-Object { -not $_.Value } | ForEach-Object { $_.Key })
        [pscustomobject]@{
            Domain = $name
            Policy = if ($policy) { $policy } else { 'No record' }
            Source = if ($source) { $source } else { 'None' }
            Failed = $failedChecks -join ', '
            Pass = $failedChecks.Count -eq 0
        }
    }
    $checked = @($report | Where-Object { $null -ne $_.Pass })
    $unchecked = @($report | Where-Object { $null -eq $_.Pass })
    if ($unchecked.Count -gt 0) {
        Add-MtTestResultDetail -SkippedBecause NotSupported
        return $null
    }
    $failed = @($checked | Where-Object { -not $_.Pass })
    $testResult = $failed.Count -eq 0

    $passText = 'All accepted domains have an enforcing DMARC policy with reporting addresses.'
    $failText = "$($failed.Count) domain(s) do not have a compliant DMARC policy."

    $resultMd = "| Domain | Applied policy | Record found at | Failed checks | Result |`n"
    $resultMd += "| --- | --- | --- | --- | --- |`n"
    foreach ($row in $report) {
        $resultMd += "| $($row.Domain) | $($row.Policy) | $($row.Source) | $(if ($row.Failed) { $row.Failed } else { 'None' }) | $(if ($null -eq $row.Pass) { 'Not checked' } elseif ($row.Pass) { '✅ Pass' } else { '❌ Fail' }) |`n"
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
