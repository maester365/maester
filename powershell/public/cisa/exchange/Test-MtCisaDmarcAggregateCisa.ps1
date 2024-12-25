<#
.SYNOPSIS
    Checks state of DMARC records for all exo domains

.DESCRIPTION
    The DMARC point of contact for aggregate reports SHALL include reports@dmarc.cyber.dhs.gov.

.EXAMPLE
    Test-MtCisaDmarcAggregateCisa

    Returns true if DMARC record with reject policy exists for every domain if a .gov domain exists

.EXAMPLE
    Test-MtCisaDmarcAggregateCisa -Force

    Returns true if DMARC record with reject policy exists for every domain

.LINK
    https://maester.dev/docs/commands/Test-MtCisaDmarcAggregateCisa
#>
function Test-MtCisaDmarcAggregateCisa {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # Check all domains, not only .gov domains.
        [switch]$Force,

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
    $tldMatch = "^.*\.(?'tld'.*)$"
    $govDomains = $acceptedDomains | Where-Object {`
        $_ -imatch $tldMatch|Out-Null;
        if($Matches.tld -eq "gov"){$_}
    }

    if(!($govDomains) -and !($Force)){
        Add-MtTestResultDetail -SkippedBecause NotDotGovDomain
        return $null
    }

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
        $checkTarget = "reports@dmarc.cyber.dhs.gov" -in ($dmarcRecords.dmarcRecord.reportAggregate.mailAddress)

        if($checkType -and $checkTarget){
            $dmarcRecord.pass = "Passed"
        }elseif($checkType -and -not $checkTarget){
            $dmarcRecord.reason = "Missing CISA report target"
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
        $testResultMarkdown = "Well done. Your tenant's domains have DMARC aggregate reports sent to CISA.`n`n%TestResult%"
    }else{
        $testResultMarkdown = "Your tenant's domains do not have DMARC aggregate reports sent to CISA.`n`n%TestResult%"
    }

    $passResult = "✅ Pass"
    $failResult = "❌ Fail"
    $result = "| Domain | Result | Reason | Targets |`n"
    $result += "| --- | --- | --- | --- |`n"
    foreach ($item in $dmarcRecords) {
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
            $aggregates = $aggregates -join ", "
        }

        $result += "| $($item.domain) | $($itemResult) | $($item.reason) | $($aggregates) |`n"
    }

    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}