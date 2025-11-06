<#
.SYNOPSIS
    Checks state of DMARC records for all exo second level domains

.DESCRIPTION
    A DMARC policy SHALL be published for every second-level domain.

.EXAMPLE
    Test-MtCisaDmarcRecordExist

    Returns true if DMARC record exists for all 2LD

.LINK
    https://maester.dev/docs/commands/Test-MtCisaDmarcRecordExist
#>
function Test-MtCisaDmarcRecordExist {
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

    $seen = @{}
    $dmarcRecords = @()
    foreach($domain in ($acceptedDomains | Sort-Object -Property DomainName -Unique)){
        #This regex does NOT capture for third level domain scenarios
        #e.g., example.co.uk; example.ny.us;
        $matchDomain = "(?:^|\.)(?'second'\w+.\w+$)"
        $dmarcMatch = $domain.domainname -match $matchDomain
        if($dmarcMatch){
            $domainName = $Matches.second
        }else{
            $domainName = $domain.domainname
        }

        if ($seen[$domainName]) {
            continue
        }
        $seen[$domainName] = $True

        $dmarcRecord = Get-MailAuthenticationRecord -DomainName $domainName -Records DMARC
        $dmarcRecord | Add-Member -MemberType NoteProperty -Name "pass" -Value "Failed"
        $dmarcRecord | Add-Member -MemberType NoteProperty -Name "reason" -Value ""

        if($dmarcRecord.dmarcRecord.GetType().Name -eq "DMARCRecord"){
            $dmarcRecord.pass = "Passed"
        }elseif($domain.IsCoexistenceDomain){
            $dmarcRecord.pass = "Skipped"
            $dmarcRecord.reason = "Coexistence domain"
        }elseif($domain.InitialDomain){
            $dmarcRecord.pass = "Skipped"
            $dmarcRecord.reason = "Initial domain"
        }elseif($dmarcRecord.dmarcRecord -like "*not available"){
            $dmarcRecord.pass = "Skipped"
            $dmarcRecord.reason = $dmarcRecord.dmarcRecord
        }elseif($domainName -eq 'onmicrosoft.com'){
            $dmarcRecord.pass = "Skipped"
            $dmarcRecord.reason = 'Not applicable'
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
        if($dmarcRecords.reason -like "*not available"){
            Add-MtTestResultDetail -SkippedBecause NotSupported
            return $null
        }else{
            Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "Skipped for $($dmarcRecords.reason)"
        }
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
    $skipResult = "🗄️ Skip"
    $result = "| Domain | Result | Reason | Targets |`n"
    $result += "| --- | --- | --- | --- |`n"
    foreach ($item in $dmarcRecords | Sort-Object -Property domain) {
        switch($item.pass){
            "Passed" {$itemResult = $passResult}
            "Failed" {$itemResult = $failResult}
            "Skipped" {$itemResult = $skipResult}
        }

        if ($item.pass -eq "Skipped") {
            $result += "| $($item.domain) | $($itemResult) | $($item.reason) ||`n"
            continue
        }

        $aggregates = $item.dmarcRecord.reportAggregate.mailAddress
        $aggregatesCount = ($aggregates|Measure-Object).Count
        if($aggregatesCount -ge 3){
            $aggregates = "$($aggregates[0]), $($aggregates[1]), "
            $aggregates += "& ...$aggregatesCount targets"
        }elseif($aggregatesCount -gt 1){
            $aggregates = $aggregates -join ", "
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