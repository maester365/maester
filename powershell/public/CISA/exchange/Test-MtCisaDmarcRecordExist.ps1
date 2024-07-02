<#
.SYNOPSIS
    Checks state of DMARC records for all exo second level domains

.DESCRIPTION

    A DMARC policy SHALL be published for every second-level domain.

.EXAMPLE
    Test-MtCisaDmarcRecordExist

    Returns true if DMARC record exists for all 2LD
#>

Function Test-MtCisaDmarcRecordExist {
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

    $dmarcRecords = @()
    foreach($domain in $acceptedDomains){
        #This regex does NOT capture for third level domain scenarios
        #e.g., example.co.uk; example.ny.us;
        $matchDomain = "(?:^|\.)(?'second'\w+.\w+$)"
        $dmarcMatch = $domain.domainname -match $matchDomain
        if($dmarcMatch){
            $domainName = $Matches.second
        }else{
            $domainName = $domain.domainname
        }

        $dmarcRecord = Get-MailAuthenticationRecord -DomainName $domainName -Records DMARC
        $dmarcRecord | Add-Member -MemberType NoteProperty -Name "pass" -Value "Failed"
        $dmarcRecord | Add-Member -MemberType NoteProperty -Name "reason" -Value ""

        if($dmarcRecord.dmarcRecord.GetType().Name -eq "DMARCRecord"){
            $dmarcRecord.pass = "Passed"
        }else{
            $dmarcRecord.reason = $dmarcRecord.dmarcRecord
        }

        $dmarcRecords += $dmarcRecord
    }

    if("Failed" -in $dmarcRecords.pass){
        $testResult = $false
    }else{
        $testResult = $true
    }

    if($testResult){
        $testResultMarkdown = "Well done. Your tenant's second level domains have a DMARC record. Review report targets.`n`n%TestResult%"
    }else{
        $testResultMarkdown = "Your tenant's second level domains do not have a DMARC record.`n`n%TestResult%"
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
            $aggregates = "$($aggregates[0])<br />$($aggregates[1])<br />"
            $aggregates += "...$aggregatesCount targets"
        }elseif(aggregatesCount -gt 1){
            $aggregates = $aggregates -join "<br />"
        }
        $forensics = $item.dmarcRecord.reportForensic.mailAddress
        $forensicsCount = ($forensics|Measure-Object).Count
        if($forensicsCount -ge 3){
            $forensics = "$($forensics[0])<br />$($forensics[1])<br />"
            $forensics += "...$forensicsCount targets"
        }elseif(aggregatesCount -gt 1){
            $forensics = $forensics -join "<br />"
        }

        $result += "| $($item.domain) | $($itemResult) | $($item.reason) | Aggregate Reports: $($aggregates) |`n"
        $result += "| $($item.domain) | $($itemResult) | $($item.reason) | Forensic Reports: $($forensics) |`n"
    }

    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}