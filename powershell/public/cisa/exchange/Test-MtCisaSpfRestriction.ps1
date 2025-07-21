<#
.SYNOPSIS
    Checks state of SPF records for all exo domains

.DESCRIPTION
    A list of approved IP addresses for sending mail SHALL be maintained.

.EXAMPLE
    Test-MtCisaSpfRestriction

    Returns true if SPF record exists and has a fail all modifier for all exo domains

.LINK
    https://maester.dev/docs/commands/Test-MtCisaSpfRestriction
#>
function Test-MtCisaSpfRestriction {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if(!(Test-MtConnection ExchangeOnline)){
        Add-MtTestResultDetail -SkippedBecause NotConnectedExchange
        return $null
    }

    $acceptedDomains = Get-MtExo -Request AcceptedDomain
    <# Parked domains should have SPF ending in -all too
    $sendingDomains = $acceptedDomains | Where-Object {`
        -not $_.SendingFromDomainDisabled
    }
    #>

    $spfRecords = @()
    foreach($domain in $acceptedDomains){
        $spfRecord = Get-MailAuthenticationRecord -DomainName $domain.DomainName -Records SPF
        $spfRecord | Add-Member -MemberType NoteProperty -Name "pass" -Value "Failed"
        $spfRecord | Add-Member -MemberType NoteProperty -Name "reason" -Value ""

        if($spfRecord.spfRecord.GetType().Name -eq "SPFRecord"){
            if ($spfRecord.spfRecord.terms[-1].directive -eq "-all"){
                $spfRecord.pass = "Passed"
                $spfRecord.reason = "Last directive is '-all'"
            } elseif ($spfRecord.spfRecord.terms[-1].modifier -eq "redirect"){
                $spfRecord.pass = "Skipped"
                $spfRecord.reason = "Redirect modifier"
            }
        } elseif ($spfRecord.spfRecord -like "*not available"){
            $spfRecord.pass = "Skipped"
            $spfRecord.reason = $spfRecord.spfRecord
        } else {
            #$spfRecord.reason = "Last directive is not '-all'"
            $spfRecord.reason = "Failure to obtain record"
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
    }else{
        $testResult = $true
    }

    if($testResult){
        $testResultMarkdown = "Well done. Your tenant's domains have a restricted SPF, review authorized senders for accuracy.`n`n%TestResult%"
    }else{
        $testResultMarkdown = "Your tenant's domains do not restrict authorized senders with SPF fully. Ensure all domain's SPF records end in '-all'.`n`n%TestResult%"
    }

    $passResult = "✅ Pass"
    $failResult = "❌ Fail"
    $skipResult = "🗄️ Skip"
    $result = "| Domain | Result | Reason | Addresses |`n"
    $result += "| --- | --- | --- | --- |`n"
    foreach ($item in $spfRecords | Sort-Object -Property domain) {
        switch($item.pass){
            "Passed" {$itemResult = $passResult}
            "Skipped" {$itemResult = $skipResult}
            "Failed" {$itemResult = $failResult}
        }
        $itemAddressCount = ($item.spfLookups.IPAddress|Measure-Object).Count
        switch($itemAddressCount){
            0 {
                $itemAddressList = ""
            }
            1 {
                $itemAddressList = "$($item.spfLookups.IPAddress[0])"
            }
            2 {
                $itemAddressList = "$($item.spfLookups.IPAddress[0]), "
                $itemAddressList += "$($item.spfLookups.IPAddress[1])"
            }
            Default {
                $itemAddressList = "$($item.spfLookups.IPAddress[0]), "
                $itemAddressList += "$($item.spfLookups.IPAddress[1]), "
                $itemAddressList += "& ...$($itemAddressCount-2) addresses"
            }
        }
        $result += "| $($item.domain) | $($itemResult) | $($item.reason) | $($itemAddressList) |`n"
    }

    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}