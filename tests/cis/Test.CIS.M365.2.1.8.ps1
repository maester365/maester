function Test-MtCisSpfRecordsPublished {
    <#
    .SYNOPSIS
        Checks the applicable CIS SPF requirement for each custom accepted domain.

    .DESCRIPTION
        Sending domains must publish an SPF record that ends with -all or ~all, directly or through a redirect. Domains listed in the ParkedDomains parameter must publish v=spf1 -all, which denies all senders. Every other domain gets the sending-domain audit. Domains in the onmicrosoft.com namespace are excluded because Microsoft manages their SPF.
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
        Author = 'JeremyFinney-lgtm',
        Contributor = ('earbona23', 'merill')
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # Domains that are not used to send email. They must publish v=spf1 -all.
        [MaesterParameter(Setting = 'ParkedDomains')]
        [string[]]$ParkedDomains = @()
    )

    Write-Verbose 'Getting accepted domains...'
    $domains = @(Get-MtExo -Request AcceptedDomain | Where-Object { $_.InitialDomain -eq $false -and $_.IsCoExistenceDomain -eq $false })

    $report = foreach ($domain in $domains) {
        $name = $domain.DomainName
        $isParked = Test-MtCisParkedDomain -DomainName $name -ParkedDomains $ParkedDomains
        $classification = if ($isParked) { 'Parked' } else { 'Sending' }
        $detail = ''
        $spf = ConvertFrom-MailAuthenticationRecordSpf -DomainName $name
        if ($spf -is [string] -and ($spf -like '*not available' -or $spf -eq 'DNS lookup unavailable')) {
            [pscustomobject]@{ Domain = $name; Record = $null; Classification = $classification; Pass = $null; Detail = 'DNS lookup not available' }
            continue
        }
        $record = if ($spf -and $spf.PSObject.Properties['record']) { $spf.record } else { $null }
        if ($isParked) {
            # CIS asks parked domains for v=spf1 -all: no sender mechanisms, no redirect, hard fail last.
            # RFC 7208 sections 7.1-7.2: validate exp's domain-spec, not the fetched explanation text.
            $macroExpand = '%(?:\{[slodiphv][0-9]*r?[.\-+,/_=]*\}|[%_-])'
            $macroString = "(?:$macroExpand|[\x21-\x24\x26-\x7E])*"
            $domainEnd = "(?:\.(?:[a-z0-9]*[a-z][a-z0-9]*|[a-z0-9]+-[a-z0-9-]*[a-z0-9])\.?|$macroExpand)"
            $pass = [string]$record -match "(?i)^\s*v=spf1(?:\s+exp=$macroString$domainEnd)?\s+-all\s*$"
            $detail = if ($pass) {
                'Listed as parked; the record denies all senders with -all.'
            } else {
                'Listed as parked; CIS requires v=spf1 -all, which denies all senders.'
            }
            [pscustomobject]@{ Domain = $name; Record = $record; Classification = $classification; Pass = $pass; Detail = $detail }
            continue
        }
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
            [pscustomobject]@{ Domain = $name; Record = $record; Classification = $classification; Pass = $null; Detail = "DNS lookup not available for $($redirectTargets[-1])" }
            continue
        }
        $effectiveTerms = [string]$effective -split '\s+'
        $allMechanisms = @($effectiveTerms | Where-Object { $_ -match '(?i)^[+?~-]?all$' })
        $effectiveAll = [regex]::Match([string]$effective, '(?i)(^|\s)(?<q>[+?~-]?)all\s*$')
        $pass = $effectiveAll.Success -and $effectiveAll.Groups['q'].Value -in '-', '~' -and $allMechanisms.Count -eq 1
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

        [pscustomobject]@{ Domain = $name; Record = $record; Classification = $classification; Pass = $pass; Detail = $detail }
    }

    $unchecked = @($report | Where-Object { $null -eq $_.Pass })
    $failed = @($report | Where-Object { $_.Pass -eq $false })
    if ($failed.Count -gt 0) {
        $testResult = $false
    } elseif ($unchecked.Count -gt 0) {
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
        $resultText = if ($null -eq $row.Pass) { 'Not checked' } elseif ($row.Pass) { '✅ Pass' } else { '❌ Fail' }
        $resultMd += "| $($row.Domain) | $($row.Classification) | $($row.Record) | $($row.Detail) | $resultText |`n"
    }

    if ($testResult) {
        $testResultMarkdown = "Well done. $passText`n`n%TestResult%"
    }
    else {
        $testResultMarkdown = "$failText`n`n%TestResult%"
    }
    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $resultMd

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
