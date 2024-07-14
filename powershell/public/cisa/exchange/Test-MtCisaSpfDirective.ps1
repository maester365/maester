﻿<#
.SYNOPSIS
    Checks state of SPF records for all exo domains

.DESCRIPTION

    An SPF policy SHALL be published for each domain, designating only these addresses as approved senders.

.EXAMPLE
    Test-MtCisaSpfDirective

    Returns true if SPF record exists and has at least one directive
#>

Function Test-MtCisaSpfDirective {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if(!(Test-MtConnection ExchangeOnline)){
        Add-MtTestResultDetail -SkippedBecause NotConnectedExchange
        return $null
    }

    $acceptedDomains = Get-AcceptedDomain
    $sendingDomains = $acceptedDomains | Where-Object {`
        -not $_.SendingFromDomainDisabled
    }

    $spfRecords = @()
    foreach($domain in $sendingDomains){
        $spfRecord = Get-MailAuthenticationRecord -DomainName $domain.DomainName -Records SPF
        $spfRecord | Add-Member -MemberType NoteProperty -Name "pass" -Value "Failed"
        $spfRecord | Add-Member -MemberType NoteProperty -Name "reason" -Value ""

        $directives = ($spfRecord.spfRecord.terms|Where-Object {`
            $_.mechanismTarget -ne ""
        }).directive

        $check = "include:spf.protection.outlook.com" -in $directives

        if(($directives|Measure-Object).Count -ge 1 -and $check){
            $spfRecord.pass = "Passed"
            $spfRecord.reason = "1+ mechanism targets"
        }elseif(($directives|Measure-Object).Count -ge 1 -and -not $check){
            $spfRecord.reason = "No EXO directive"
        }elseif($spfRecord.spfRecord -like "*not available"){
            $spfRecord.pass = "Skipped"
            $spfRecord.reason = $spfRecord.spfRecord
        }elseif($spfRecord.spfRecord.GetType().Name -eq "SPFRecord"){
            if($spfRecord.spfRecord.terms[-1].modifier -eq "redirect"){
                $spfRecord.pass = "Skipped"
                $spfRecord.reason = "Redirect modifier"
            }
        }else{
            $spfRecord.reason = "No mechanism targets"
        }

        #Hacky sort, doesn't handle IPv6
        #$spfRecord.spfLookups.IPAddress|sort -Property {[system.version]($_ -replace "\/\d{1,3}$","")}
        #Proper but will need to update Resolve-SPFRecord
        #Too: https://learn.microsoft.com/en-us/dotnet/api/system.net.ipnetwork
        #[ipaddress]::HostToNetworkOrder(([ipaddress]$_).address)

        $spfRecords += $spfRecord
    }

    if("Failed" -in $spfRecords.pass){
        $testResult = $false
    }elseif("Failed" -notin $spfRecords.pass -and "Passed" -notin $spfRecords.pass){
        Add-MtTestResultDetail -SkippedBecause NotSupported
        return $null
    }else{
        $testResult = $true
    }

    if($testResult){
        $testResultMarkdown = "Well done. Your tenant's domains have at least 1 directives with specific mechanism targets, review authorized senders for accuracy.`n`n%TestResult%"
    }else{
        $testResultMarkdown = "Your tenant's domains do not restrict authorized senders with SPF fully. Ensure authorized senders are specified.`n`n%TestResult%"
    }

    $passResult = "✅ Pass"
    $failResult = "❌ Fail"
    $skipResult = "🗄️ Skip"
    $result = "| Domain | Result | Reason | Directives |`n"
    $result += "| --- | --- | --- | --- |`n"
    foreach ($item in $spfRecords | Sort-Object -Property domain) {
        switch($item.pass){
            "Passed" {$itemResult = $passResult}
            "Skipped" {$itemResult = $skipResult}
            "Failed" {$itemResult = $failResult}
        }
        $itemDirectives = ($item.spfRecord.terms|Where-Object {`
            $_.mechanismTarget -ne ""
        }).directive
        $itemDirectiveCount = ($itemDirectives|Measure-Object).Count
        switch($itemDirectiveCount){
            0 {
                $itemList = ""
            }
            1 {
                $itemList = "$($itemDirectives)"
            }
            2 {
                $itemList = "$($itemDirectives[0]), "
                $itemList += "$($itemDirectives[1])"
            }
            Default {
                $itemList = "$($itemDirectives[0]), "
                $itemList += "$($itemDirectives[1]), "
                $itemList += "& ...$($itemDirectiveCount) directives"
            }
        }
        $result += "| $($item.domain) | $($itemResult) | $($item.reason) | $($itemList) |`n"
    }

    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}