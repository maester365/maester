function Test-MtCisSpfRecordsPublished {
    <#
    .SYNOPSIS
        Checks the applicable CIS SPF requirement for each custom accepted domain.

    .DESCRIPTION
        Sending domains must publish an SPF record that ends with -all or ~all, directly or through a redirect. Parked or otherwise non-sending domains must publish an SPF policy that denies all senders with -all. Domains in the onmicrosoft.com namespace are excluded because Microsoft manages their SPF. Ambiguous domain-use evidence is reported for investigation rather than receiving the parked-domain exception.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (2.1.8, L1)

    .EXAMPLE
        Test-MtCisSpfRecordsPublished

        Returns true if all custom domains meet the applicable CIS SPF requirement.

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
    param(
        # Domains explicitly confirmed as parked; the parked SPF audit still applies.
        [string[]]$ParkedDomains = @()
    )

    Write-Verbose 'Getting accepted domains...'
    $domains = @(Get-MtExo -Request AcceptedDomain | Where-Object { $_.InitialDomain -eq $false -and $_.IsCoExistenceDomain -eq $false })
    $dkimSigningConfigs = @(Get-MtExo -Request DkimSigningConfig)

    $report = foreach ($domain in $domains) {
        $name = $domain.DomainName
        $classification = Get-MtCisParkedDomainClassification -DomainName $name -DkimSigningConfigs $dkimSigningConfigs -ParkedDomains $ParkedDomains
        $detail = ''
        $spf = ConvertFrom-MailAuthenticationRecordSpf -DomainName $name
        if ($spf -is [string] -and ($spf -like '*not available' -or $spf -eq 'DNS lookup unavailable')) {
            [pscustomobject]@{ Domain = $name; Record = $null; Classification = $classification.Classification; Pass = $null; Investigate = $false; Detail = 'DNS lookup not available' }
            continue
        }
        $record = if ($spf -and $spf.PSObject.Properties['record']) { $spf.record } else { $null }
        $effective = $record
        $redirectTargets = @()
        $redirectError = $null
        $redirectUnavailable = $false
        $visitedDomains = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        $null = $visitedDomains.Add($name)

        while ($effective) {
            # RFC 7208 section 5.1: a redirect is ignored when the record has an all mechanism.
            $localAll = [regex]::Match([string]$effective, '(?i)(^|\s)(?<q>[+?~-]?)all(\s|$)')
            if ($localAll.Success) { break }

            $redirect = [regex]::Match([string]$effective, '(?i)(?:^|\s)redirect=(?<target>[^\s;]+)')
            if (-not $redirect.Success) { break }
            $target = $redirect.Groups['target'].Value

            if ($redirectTargets.Count -ge 9) {
                $redirectError = 'The redirect chain exceeds the DNS lookup limit.'
                break
            }
            if (-not $visitedDomains.Add($target)) {
                $redirectError = "The redirect chain contains a cycle at $target."
                break
            }

            $redirectTargets += $target
            $redirected = ConvertFrom-MailAuthenticationRecordSpf -DomainName $target
            if ($redirected -is [string] -and ($redirected -like '*not available' -or $redirected -eq 'DNS lookup unavailable')) {
                $redirectUnavailable = $true
                break
            }
            $effective = if ($null -ne $redirected -and $redirected.PSObject.Properties['record']) { $redirected.record } else { $null }
            if (-not $effective) {
                $redirectError = "No SPF record was found at redirect target $target."
                break
            }
        }

        if ($redirectUnavailable) {
            [pscustomobject]@{ Domain = $name; Record = $record; Classification = $classification.Classification; Pass = $null; Investigate = $false; Detail = "DNS lookup not available for $($redirectTargets[-1])" }
            continue
        }
        $effectiveAll = [regex]::Match([string]$effective, '(?i)(^|\s)(?<q>[+?~-]?)all\s*$')
        $sendingDomainPass = $effectiveAll.Success -and $effectiveAll.Groups['q'].Value -in '-', '~'
        $pass = $sendingDomainPass
        $investigate = $false
        if (-not $record) {
            $detail = 'No SPF record found'
        } elseif ($redirectError) {
            $detail = $redirectError
        } elseif ($redirectTargets.Count -gt 0 -and -not $pass) {
            $detail = "The effective record after redirecting to $($redirectTargets -join ' -> ') does not end with -all or ~all"
        } elseif ($redirectTargets.Count -gt 0) {
            $detail = "Redirects to $($redirectTargets -join ' -> ')"
        }
        elseif (-not $pass) {
            $detail = 'The record does not end with -all or ~all'
        }

        if ($classification.Classification -in @('Parked', 'NotSending')) {
            $pass = $classification.SpfDeniesAll
            $detail = if ($pass) {
                'The parked/non-sending audit requires an SPF record that explicitly denies all senders; this record uses -all.'
            } else {
                'The parked/non-sending audit requires an SPF record that explicitly denies all senders with -all.'
            }
        } elseif ($classification.Classification -eq 'Unknown' -and $sendingDomainPass -and -not $classification.SpfDeniesAll) {
            $pass = $null
            $investigate = $true
            $detail = 'The sending-domain SPF audit passes, but the available evidence cannot rule out the parked-domain requirement for -all.'
        } elseif ($classification.Classification -eq 'Unknown' -and $sendingDomainPass) {
            $pass = $true
            $detail = 'The record meets both the sending-domain and parked-domain SPF requirements.'
        }

        $detail = "$($classification.Reason) $detail"
        [pscustomobject]@{ Domain = $name; Record = $record; Classification = $classification.Classification; Pass = $pass; Investigate = $investigate; Detail = $detail }
    }

    $unchecked = @($report | Where-Object { $null -eq $_.Pass -and -not $_.Investigate })
    $failed = @($report | Where-Object { $_.Pass -eq $false })
    $investigated = @($report | Where-Object { $_.Investigate })
    if ($failed.Count -gt 0) {
        $testResult = $false
    } elseif ($unchecked.Count -gt 0 -and $investigated.Count -eq 0) {
        Add-MtTestResultDetail -SkippedBecause NotSupported
        return $null
    } else {
        $testResult = $true
    }

    $passText = if ($domains.Count -eq 0) { 'There are no custom domains, so no SPF records are required.' } else { 'All custom domains meet the applicable CIS SPF requirement.' }
    $failText = "$($failed.Count) custom domain(s) do not meet the applicable CIS SPF requirement."

    $resultMd = "| Domain | Classification | SPF record | Detail | Result |`n"
    $resultMd += "| --- | --- | --- | --- | --- |`n"
    foreach ($row in $report) {
        $resultText = if ($null -eq $row.Pass -and $row.Investigate) { 'Investigate' } elseif ($null -eq $row.Pass) { 'Not checked' } elseif ($row.Pass) { '✅ Pass' } else { '❌ Fail' }
        $resultMd += "| $($row.Domain) | $($row.Classification) | $($row.Record) | $($row.Detail) | $resultText |`n"
    }

    if ($testResult) {
        $testResultMarkdown = "Well done. $passText`n`n%TestResult%"
    }
    else {
        $testResultMarkdown = "$failText`n`n%TestResult%"
    }
    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $resultMd

    Add-MtTestResultDetail -Result $testResultMarkdown -Investigate:($investigated.Count -gt 0 -and $failed.Count -eq 0)
    return $testResult
}
