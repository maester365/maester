<#
.SYNOPSIS
    Checks state of DMARC records for all exo domains

.DESCRIPTION
    An agency point of contact SHOULD be included for aggregate and failure reports.

.EXAMPLE
    Test-MtCisaDmarcReport

    Returns true if DMARC record inlcudes report targets within same domain

.PARAMETER Strict
    Require the CISA explicit 2nd level validation

.LINK
    https://maester.dev/docs/commands/Test-MtCisaDmarcReport
#>
function Test-MtCisaDmarcReport {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # Check 2nd Level Domains Explicitly per CISA
        [switch]$Strict
    )

    if(!(Test-MtConnection ExchangeOnline)){
        Add-MtTestResultDetail -SkippedBecause NotConnectedExchange
        return $null
    }

    $acceptedDomains = Get-MtExo -Request AcceptedDomain
    <# Parked domains should have DMARC with reject policy
    $sendingDomains = $acceptedDomains | Where-Object {`
        -not $_.SendingFromDomainDisabled
    }
    #>
    $expandedDomains = @()
    foreach($domain in $acceptedDomains){
        #This regex does NOT capture for third level domain scenarios
        #e.g., example.co.uk; example.ny.us;
        $matchDomain = "(?:^|\.)(?'second'\w+.\w+$)"
        $dmarcMatch = $domain.domainname -match $matchDomain
        if($dmarcMatch){
            $expandedDomains += $Matches.second
            if($domain.domainname -ne $Matches.second){
                $expandedDomains += $domain.domainname
            }
        }else{
            $expandedDomains += $domain.domainname
        }
    }

    $dmarcRecords = @()
    foreach($expandedDomain in $expandedDomains){
        $dmarcRecord = Get-MailAuthenticationRecord -DomainName $expandedDomain -Records DMARC
        $dmarcRecord | Add-Member -MemberType NoteProperty -Name "pass" -Value "Failed"
        $dmarcRecord | Add-Member -MemberType NoteProperty -Name "reason" -Value ""

        $checkType = $dmarcRecord.dmarcRecord.GetType().Name -eq "DMARCRecord"
        $hostsAggregate = $dmarcRecord.dmarcRecord.reportAggregate.mailAddress.Host
        $hostsForensic = $dmarcRecord.dmarcRecord.reportForensic.mailAddress.Host

        if($checkType -and $expandedDomain -in $hostsAggregate -and $expandedDomain -in $hostsForensic){
            $dmarcRecord.pass = "Passed"
        }elseif($checkType){
            $dmarcRecord.reason = "No target in domain"
        }elseif($dmarcRecord.dmarcRecord -like "*not available"){
            $dmarcRecord.pass = "Skipped"
            $dmarcRecord.reason = $dmarcRecord.dmarcRecord
        }else{
            $dmarcRecord.reason = $dmarcRecord.dmarcRecord
        }

        $dmarcRecords += $dmarcRecord
    }

    if("Failed" -in $dmarcRecords.pass -and $Strict){
        $testResult = $false
    }elseif("Failed" -in $dmarcRecords.pass -and -not $Strict){
        if("Failed" -in ($dmarcRecords|Where-Object{$_.domain -in $acceptedDomains.DomainName}).pass){
            $testResult = $false
        }else{
            $testResult = $true
        }
    }elseif("Failed" -notin $dmarcRecords.pass -and "Passed" -notin $dmarcRecords.pass){
        Add-MtTestResultDetail -SkippedBecause NotSupported
        return $null
    }else{
        $testResult = $true
    }

    if($testResult){
        $testResultMarkdown = "Well done. Your tenant's domains have in domain report targets. Review report targets.`n`n%TestResult%"
    }else{
        $testResultMarkdown = "Your tenant's second level domains do not have in domain report targets.`n`n%TestResult%"
    }

    $passResult = "✅ Pass"
    $failResult = "❌ Fail"
    $result = "| Domain | Result | Reason | Targets |`n"
    $result += "| --- | --- | --- | --- |`n"
    foreach ($item in $dmarcRecords | Sort-Object -Property domain) {
        switch($item.pass){
            "Passed" {$itemResult = $passResult}
            "Failed" {$itemResult = $failResult}
        }
        $aggregates = $item.dmarcRecord.reportForensic.mailAddress
        $aggregatesCount = ($aggregates|Measure-Object).Count
        if($aggregatesCount -ge 3){
            $aggregates = "$($aggregates[0]), $($aggregates[1]), "
            $aggregates += "& ...$aggregatesCount targets"
        }elseif($aggregatesCount -gt 1){
            $aggregates = $aggregates -join "<br />"
        }
        $forensics = $item.dmarcRecord.reportForensic.mailAddress
        $forensicsCount = ($forensics|Measure-Object).Count
        if($forensicsCount -ge 3){
            $forensics = "$($forensics[0]), $($forensics[1]), "
            $forensics += "& ...$forensicsCount targets"
        }elseif($aggregatesCount -gt 1){
            $forensics = $forensics -join ", "
        }

        $result += "| $($item.domain) | $($itemResult) | $($item.reason) | Aggregate Reports: $($aggregates) |`n"
        $result += "| $($item.domain) | $($itemResult) | $($item.reason) | Forensic Reports: $($forensics) |`n"
    }

    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}