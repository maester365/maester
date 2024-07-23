﻿<#
.SYNOPSIS
    Checks state of DMARC records for all exo domains

.DESCRIPTION
    The DMARC message rejection option SHALL be p=reject.

.EXAMPLE
    Test-MtCisaDmarcRecordExist

    Returns true if DMARC record with reject policy exists for every domain

.LINK
    https://maester.dev/docs/commands/Test-MtCisaDmarcRecordReject
#>
function Test-MtCisaDmarcRecordReject {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if(!(Test-MtConnection ExchangeOnline)){
        Add-MtTestResultDetail -SkippedBecause NotConnectedExchange
        return $null
    }

    $acceptedDomains = Get-AcceptedDomain
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
    foreach($domain in $expandedDomains){
        $dmarcRecord = Get-MailAuthenticationRecord -DomainName $domain -Records DMARC
        $dmarcRecord | Add-Member -MemberType NoteProperty -Name "pass" -Value "Failed"
        $dmarcRecord | Add-Member -MemberType NoteProperty -Name "reason" -Value ""

        $checkType = $dmarcRecord.dmarcRecord.GetType().Name -eq "DMARCRecord"

        if($checkType -and $dmarcRecord.dmarcRecord.policy -eq "reject"){
            $dmarcRecord.pass = "Passed"
        }elseif($checkType -and $dmarcRecord.dmarcRecord.policy -ne "reject"){
            $dmarcRecord.reason = "Policy is not reject"
        }elseif($checkType -and $dmarcRecord.dmarcRecord.policySubdomain -in @("none","quarantine")){
            $dmarcRecord.reason = "Subdomain policy is not reject"
        }elseif($dmarcRecord.dmarcRecord -like "*not available"){
            $dmarcRecord.pass = "Skipped"
            $dmarcRecord.reason = $dmarcRecord.dmarcRecord
        }else{
            $dmarcRecord.reason = $dmarcRecord.dmarcRecord
        }

        $dmarcRecords += $dmarcRecord
    }

    if("Failed" -in $dmarcRecords.pass){
        $testResult = $false
    }elseif("Failed" -notin $dmarcRecords.pass -and "Passed" -notin $dmarcRecords.pass){
        Add-MtTestResultDetail -SkippedBecause NotSupported
        return $null
    }else{
        $testResult = $true
    }

    if($testResult){
        $testResultMarkdown = "Well done. Your tenant's domains have a DMARC record with reject policy. Review report targets.`n`n%TestResult%"
    }else{
        $testResultMarkdown = "Your tenant's domains do not have a DMARC record with reject policy.`n`n%TestResult%"
    }

    $passResult = "✅ Pass"
    $failResult = "❌ Fail"
    $result = "| Domain | Result | Reason | Policy | Subdomain Poliy |`n"
    $result += "| --- | --- | --- | --- | --- |`n"
    foreach ($item in $dmarcRecords) {
        switch($item.pass){
            "Passed" {$itemResult = $passResult}
            "Failed" {$itemResult = $failResult}
        }

        $result += "| $($item.domain) | $($itemResult) | $($item.reason) | $($item.dmarcRecord.policy) | $($item.dmarcRecord.policySubdomain) |`n"
    }

    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}