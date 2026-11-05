function Test-MtCisDmarcRecordsPublished {
    <#
    .SYNOPSIS
        Checks the applicable CIS DMARC requirement for each accepted domain.

    .DESCRIPTION
        Looks up the DMARC record that applies to each accepted domain, falling back to the organisational domain when the domain has no valid record, including a malformed record. Sending domains require quarantine or reject, 100 percent coverage, and mailto aggregate (rua) and forensic (ruf) report addresses. Parked or otherwise non-sending domains require a valid record with p=reject. Ambiguous domain-use evidence is reported for investigation when the two procedures produce different results.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (2.1.10, L1)

    .EXAMPLE
        Test-MtCisDmarcRecordsPublished

        Returns true if all accepted domains meet the applicable CIS DMARC requirement.

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
    param(
        # Domains explicitly confirmed as parked; the parked DMARC audit still applies.
        [string[]]$ParkedDomains = @()
    )

    Write-Verbose 'Getting accepted domains...'
    $domains = @(Get-MtExo -Request AcceptedDomain | Where-Object { $_.IsCoExistenceDomain -eq $false })
    $dkimSigningConfigs = @(Get-MtExo -Request DkimSigningConfig)

    $report = foreach ($domain in $domains) {
        $name = $domain.DomainName
        $classification = Get-MtCisParkedDomainClassification -DomainName $name -DkimSigningConfigs $dkimSigningConfigs -ParkedDomains $ParkedDomains
        $dmarc = $null
        $source = $null
        $unavailable = $false
        $invalidCandidate = $null
        # DMARC policy discovery uses the domain, then its organisational domain only.
        $candidates = @($name, (Get-MtRegistrableDomain -DomainName $name)) | Select-Object -Unique
        foreach ($candidate in $candidates) {
            $found = ConvertFrom-MailAuthenticationRecordDmarc -DomainName $candidate
            if ($found -is [string]) {
                if ($found -like '*not available' -or $found -eq 'DNS lookup unavailable') { $unavailable = $true; break }
                if ($found -eq 'Invalid DMARC record') { $invalidCandidate = $candidate }
                continue
            }
            if ($null -ne $found -and $found -isnot [string]) {
                $dmarc = $found
                $source = $candidate
                break
            }
        }
        if ($unavailable) {
            [pscustomobject]@{ Domain = $name; Classification = $classification.Classification; Policy = 'Not checked'; Source = 'None'; Failed = 'DNS lookup not available'; Pass = $null; Investigate = $false }
            continue
        }
        $policy = $null
        if ($dmarc) {
            $policy = if ($source -ne $name -and $dmarc.policySubdomain) { $dmarc.policySubdomain } else { $dmarc.policy }
        }
        $sendingChecks = [ordered]@{
            'Record is valid' = $null -ne $dmarc -and $dmarc.valid
            'Policy is quarantine or reject' = $policy -in @('quarantine', 'reject')
            'Applies to 100 percent' = $null -eq $dmarc -or $dmarc.percentage -eq 100 -or $null -eq $dmarc.percentage
            'Aggregate reports (rua)' = @($dmarc.reportAggregate | Where-Object { $_.mailAddress }).Count -gt 0
            'Forensic reports (ruf)' = @($dmarc.reportForensic | Where-Object { $_.mailAddress }).Count -gt 0
        }
        $nonSendingChecks = [ordered]@{
            'Record is valid' = $null -ne $dmarc -and $dmarc.valid
            'Parked-domain policy is reject' = $policy -eq 'reject'
        }
        $sendingFailures = @($sendingChecks.GetEnumerator() | Where-Object { -not $_.Value } | ForEach-Object { $_.Key })
        $nonSendingFailures = @($nonSendingChecks.GetEnumerator() | Where-Object { -not $_.Value } | ForEach-Object { $_.Key })
        $failedChecks = @()
        $investigate = $false
        if ($classification.Classification -in @('Parked', 'NotSending')) {
            $failedChecks = $nonSendingFailures
            $pass = $failedChecks.Count -eq 0
        } elseif ($classification.Classification -eq 'Unknown') {
            if ($sendingFailures.Count -eq 0 -and $nonSendingFailures.Count -eq 0) {
                $pass = $true
            } elseif ($sendingFailures.Count -eq 0 -or $nonSendingFailures.Count -eq 0) {
                $pass = $true
                $investigate = $true
                $failedChecks = if ($sendingFailures.Count -eq 0) {
                    @("If parked or non-sending: $($nonSendingFailures -join ', ')")
                } else {
                    @("If sending: $($sendingFailures -join ', ')")
                }
            } else {
                $pass = $false
                $failedChecks = @(
                    @($sendingFailures | ForEach-Object { "If sending: $_" }) +
                    @($nonSendingFailures | ForEach-Object { "If parked or non-sending: $_" })
                )
            }
        } else {
            $failedChecks = $sendingFailures
            $pass = $failedChecks.Count -eq 0
        }
        [pscustomobject]@{
            Domain         = $name
            Classification = $classification.Classification
            Policy         = if ($policy) { $policy } elseif ($invalidCandidate) { 'Invalid DMARC record' } else { 'No valid record' }
            Source         = if ($source) { $source } elseif ($invalidCandidate) { $invalidCandidate } else { 'None' }
            Failed         = $failedChecks -join ', '
            Pass           = $pass
            Investigate    = $investigate
        }
    }
    $checked = @($report | Where-Object { $null -ne $_.Pass })
    $unchecked = @($report | Where-Object { $null -eq $_.Pass -and -not $_.Investigate })
    $failed = @($checked | Where-Object { -not $_.Pass })
    $investigated = @($report | Where-Object { $_.Investigate })
    if ($failed.Count -eq 0 -and $unchecked.Count -gt 0 -and $investigated.Count -eq 0) {
        Add-MtTestResultDetail -SkippedBecause NotSupported
        return $null
    }
    $testResult = $failed.Count -eq 0

    $passText = 'All accepted domains meet the applicable CIS DMARC requirement.'
    $failText = "$($failed.Count) domain(s) do not have a compliant DMARC policy."

    $resultMd = "| Domain | Classification | Applied policy | Record found at | Failed checks | Result |`n"
    $resultMd += "| --- | --- | --- | --- | --- | --- |`n"
    foreach ($row in $report) {
        $resultText = if ($row.Investigate) { 'Investigate' } elseif ($null -eq $row.Pass) { 'Not checked' } elseif ($row.Pass) { '✅ Pass' } else { '❌ Fail' }
        $resultMd += "| $($row.Domain) | $($row.Classification) | $($row.Policy) | $($row.Source) | $(if ($row.Failed) { $row.Failed } else { 'None' }) | $resultText |`n"
    }

    if ($testResult) {
        $testResultMarkdown = "Well done. $passText`n`n%TestResult%"
    } else {
        $testResultMarkdown = "$failText`n`n%TestResult%"
    }
    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $resultMd

    Add-MtTestResultDetail -Result $testResultMarkdown -Investigate:($investigated.Count -gt 0 -and $failed.Count -eq 0)
    return $testResult
}
