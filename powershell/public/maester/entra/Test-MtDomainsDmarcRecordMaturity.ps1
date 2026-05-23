function Test-MtDomainsDmarcRecordMaturity {
    <#
    .SYNOPSIS
    Checks maturity of policies and percentage values in DMARC records for all Entra registered domains.

    .DESCRIPTION
    A DMARC policy SHALL be published for every managed and verified domain in the Entra tenant.
    The DMARC record should have a policy of reject and a percentage value of 100% to be considered mature and passing the test.
    Any policy with `pct` < 100 or `quarantine` policy will result in a "Low" severity fail.
    `none` policies result in a failed test with "Medium" severity, assuming that only fully missing DMARC entry results in a "High" severity.

    Domains that are newly registered (initial), do not have DMARC information available, or are not applicable (e.g., onmicrosoft.com) will be skipped with appropriate reasons provided in the test details.

    By ensuring that all managed and verified domains have a mature DMARC record, organizations can significantly reduce the risk of email spoofing and phishing attacks, thereby enhancing their overall security posture.

    For more information on DMARC record maturity and best practices, please refer to the following resources:
    - DMARC.org: https://dmarc.org/
    - Microsoft Documentation on DMARC: https://docs.microsoft.com/en-us/microsoft-365/security/office-365-security/use-dmarc-to-validate-email?view=o365-worldwide

    .EXAMPLE
    Test-MtDomainsDmarcRecordMaturity

    Returns true if all DMARC records for managed and verified domains have a policy of reject and a percentage value of 100%. Otherwise, returns false with details on the maturity status of each domain's DMARC record.

    .LINK
    https://maester.dev/docs/commands/Test-MtDomainsDmarcRecordMaturity
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
    )

    if (!(Test-MtConnection Graph)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedGraph
        return $null
    }

    Write-Verbose 'Get verified and managed domain details for DMARC record check'
    $domains = Invoke-MtGraphRequest -RelativeUri 'domains'
    $verifiedManagedDomains = $domains | Where-Object { $_.isVerified -eq $true -and $_.authenticationType -eq "Managed" }

    if (!$verifiedManagedDomains) {
        Add-MtTestResultDetail -SkippedBecause "No verified and managed domains found in tenant"
        return $null
    }

    $dmarcRecords = @()
    $seen = @{}
    $severityRank = @{
        ''         = 0
        'Info'     = 1
        'Low'      = 2
        'Medium'   = 3
        'High'     = 4
        'Critical' = 5
    }
    $maxSeverity = ''

    foreach ($domain in ($verifiedManagedDomains | Sort-Object -Property id -Unique)) {
        $domainName = Get-MtRegistrableDomain -DomainName $domain.id

        if ($seen[$domainName]) {
            continue
        }
        $seen[$domainName] = $true

        $dmarcRecord = Get-MailAuthenticationRecord -DomainName $domainName -Records DMARC
        $dmarcRecord | Add-Member -MemberType NoteProperty -Name "pass" -Value "Failed"
        $dmarcRecord | Add-Member -MemberType NoteProperty -Name "reason" -Value ""
        $dmarcRecord | Add-Member -MemberType NoteProperty -Name "severity" -Value "" -Force

        if ($domain.isInitial) {
            $dmarcRecord.pass = 'Skipped'
            $dmarcRecord.reason = 'Initial domain'
        } elseif ($domainName -eq 'onmicrosoft.com') {
            $dmarcRecord.pass = 'Skipped'
            $dmarcRecord.reason = 'Not applicable'
        } elseif ($dmarcRecord.dmarcRecord -is [string] -and $dmarcRecord.dmarcRecord -like '*not available*') {
            $dmarcRecord.pass = 'Skipped'
            $dmarcRecord.reason = $dmarcRecord.dmarcRecord
        } elseif ($dmarcRecord.dmarcRecord -and $dmarcRecord.dmarcRecord.GetType().Name -eq 'DMARCRecord') {
            $policy = [string]$dmarcRecord.dmarcRecord.policy
            $pct = [int]$dmarcRecord.dmarcRecord.percentage

            if ($policy -eq 'reject' -and $pct -eq 100) {
                $dmarcRecord.pass = 'Passed'
                $dmarcRecord.reason = 'Mature DMARC policy (p=reject, pct=100) is published'
            } elseif ($policy -eq 'none') {
                $dmarcRecord.pass = 'Failed'
                $dmarcRecord.severity = 'Medium'
                $dmarcRecord.reason = 'Policy is none'
            } elseif ($policy -eq 'quarantine' -or $pct -lt 100) {
                $dmarcRecord.pass = 'Failed'
                $dmarcRecord.severity = 'Low'

                if ($policy -eq 'quarantine' -and $pct -lt 100) {
                    $dmarcRecord.reason = 'Policy is quarantine and pct is below 100'
                } elseif ($policy -eq 'quarantine') {
                    $dmarcRecord.reason = 'Policy is quarantine'
                } else {
                    $dmarcRecord.reason = 'pct is below 100'
                }
            } else {
                $dmarcRecord.pass = 'Failed'
                $dmarcRecord.severity = 'Low'
                $dmarcRecord.reason = 'Unexpected DMARC policy or pct value'
            }
        } else {
            $dmarcRecord.pass = 'Failed'
            $dmarcRecord.severity = 'High'
            $dmarcRecord.reason = [string]$dmarcRecord.dmarcRecord
        }

        if ($dmarcRecord.pass -eq 'Failed' -and $severityRank[$dmarcRecord.severity] -gt $severityRank[$maxSeverity]) {
            $maxSeverity = $dmarcRecord.severity
        }

        $dmarcRecords += $dmarcRecord
    }

    if ('Failed' -notin $dmarcRecords.pass -and 'Passed' -notin $dmarcRecords.pass) {
        if ($dmarcRecords.reason -like '*not available*') {
            Add-MtTestResultDetail -SkippedBecause NotSupported
        } else {
            Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason ("Skipped for " + ($dmarcRecords.reason -join ', '))
        }
        return $null
    }

    $testResult = 'Failed' -notin $dmarcRecords.pass

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant domains have mature DMARC records (p=reject, pct=100).`n`n%TestResult%"
    } else {
        $testResultMarkdown = "Some tenant domains do not have mature DMARC records (p=reject, pct=100).`n`n%TestResult%"
    }

    $passResult = '✅ Pass'
    $failResult = '❌ Fail'
    $skipResult = '🗄️ Skip'

    $result = "| Domain | Result | Severity | Policy | Pct | Reason |`n"
    $result += "| --- | --- | --- | --- | --- | --- |`n"

    foreach ($item in $dmarcRecords) {
        switch ($item.pass) {
            'Passed' { $itemResult = $passResult }
            'Skipped' { $itemResult = $skipResult }
            default { $itemResult = $failResult }
        }

        $severityText = if ([string]::IsNullOrEmpty($item.severity)) { '-' } else { $item.severity }

        if ($item.dmarcRecord -and $item.dmarcRecord.GetType().Name -eq 'DMARCRecord') {
            $policyText = if ([string]::IsNullOrEmpty([string]$item.dmarcRecord.policy)) { '-' } else { [string]$item.dmarcRecord.policy }
            $pctText = [string][int]$item.dmarcRecord.percentage
        } else {
            $policyText = '-'
            $pctText = '-'
        }

        $result += "| $($item.domain) | $itemResult | $severityText | $policyText | $pctText | $($item.reason) |`n"
    }

    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $result

    if ([string]::IsNullOrEmpty($maxSeverity)) {
        Add-MtTestResultDetail -Result $testResultMarkdown
    } else {
        Add-MtTestResultDetail -Result $testResultMarkdown -Severity $maxSeverity
    }

    return $testResult
}
