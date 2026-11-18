function Test-MtCisaSpfDirective {
    <#
    .SYNOPSIS
    Checks state of SPF records for all exo domains

    .DESCRIPTION
    An SPF policy SHALL be published for each domain, designating only these addresses as approved senders.

    .EXAMPLE
    Test-MtCisaSpfDirective

    Returns true if SPF record exists and has at least one directive

    .EXAMPLE
    Test-MtCisaSpfDirective -ParkedDomains 'contoso-old.com'

    Checks contoso-old.com as a domain that never sends email: its SPF policy must end in -all or ~all

    .LINK
    https://maester.dev/docs/commands/Test-MtCisaSpfDirective
    #>
    [MaesterTest(
        Id = 'CISA.MS.EXO.2.2',
        Title = 'An SPF policy SHALL be published for each domain, designating only these addresses as approved senders.',
        Product = 'exchange',
        Feature = 'email-authentication',
        Area = 'email-protection',
        ResourceType = 'Domain',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Medium',
        Mitre = ('T1566', 'T1684.002'),
        Control = 'cisa-scuba:MS.EXO.2.2',
        Service = 'ExchangeOnline',
        Author = 'soulemike',
        Contributor = 'moorereason'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # Domains that never send email.
        [MaesterParameter(Setting = 'ParkedDomains')]
        [string[]] $ParkedDomains = @()
    )

    $acceptedDomains = Get-MtExo -Request AcceptedDomain
    # A domain is parked only when it is listed. Exchange's SendingFromDomainDisabled is not read: SCuBA asks
    # for an SPF policy on every domain, so a domain that is not listed gets the check for a sending domain.
    $parkedDomainNames = @($ParkedDomains | ForEach-Object { "$_".Trim().TrimEnd('.') } | Where-Object { $_ })

    $spfRecords = @()
    foreach($domain in $acceptedDomains){
        $spfRecord = Get-MailAuthenticationRecord -DomainName $domain.DomainName -Records SPF
        $spfRecord | Add-Member -MemberType NoteProperty -Name "pass" -Value "Failed" -ErrorAction Ignore
        $spfRecord | Add-Member -MemberType NoteProperty -Name "reason" -Value "" -ErrorAction Ignore

        if($domain.DomainName -in $parkedDomainNames){
            # A parked domain has no approved senders, so it has no Exchange Online directive to look for.
            # MS.EXO.2.2v3 still asks for a policy that fails every other sender: -all or ~all.
            $parkedRecord = $spfRecord.spfRecord
            # The lookup returns a string when it finds no record or cannot run.
            $allTerm = if($parkedRecord -isnot [string]){
                $parkedRecord.terms | Where-Object { $_.mechanism -eq 'all' } | Select-Object -First 1
            }
            if($parkedRecord -is [string]){
                if($parkedRecord -like "*not available"){
                    $spfRecord.pass = "Skipped"
                }
                $spfRecord.reason = "Parked domain: $parkedRecord"
            }elseif($allTerm -and $allTerm.qualifier -in @('-', '~')){
                $spfRecord.pass = "Passed"
                $spfRecord.reason = "Parked domain: fails all senders"
            }elseif(-not $allTerm -and $parkedRecord.terms -and $parkedRecord.terms[-1].modifier -eq "redirect"){
                $spfRecord.pass = "Skipped"
                $spfRecord.reason = "Parked domain: redirect modifier"
            }else{
                $spfRecord.reason = "Parked domain: policy does not end in -all or ~all"
            }
            $spfRecords += $spfRecord
            continue
        }

        $directives = ($spfRecord.spfLookups | Where-Object {$_.Include}).SPFSourceDomain | Select-Object -Unique

        $check = "spf.protection.outlook.com" -in $directives -or "outlook.com" -in $directives

        if(($directives|Measure-Object).Count -ge 1 -and $check){
            $spfRecord.pass = "Passed"
            $spfRecord.reason = "1+ mechanism targets"
        }elseif($domain.IsCoexistenceDomain){
            $spfRecord.pass = "Skipped"
            $spfRecord.reason = "coexistence domain"
        }elseif(($directives|Measure-Object).Count -ge 1 -and -not $check){
            $spfRecord.reason = "No Exchange Online directive"
        }elseif($spfRecord.spfRecord -like "*not available"){
            $spfRecord.pass = "Skipped"
            $spfRecord.reason = $spfRecord.spfRecord
        }elseif($spfRecord.spfRecord.GetType().Name -eq "SPFRecord"){
            if($spfRecord.spfRecord.terms[-1].modifier -eq "redirect"){
                $spfRecord.pass = "Skipped"
                $spfRecord.reason = "Redirect modifier"
            }
        }else{
            #$spfRecord.reason = "No mechanism targets"
            $spfRecord.reason = "Failure to obtain record"
        }

        #Hacky sort, doesn't handle IPv6
        #$spfRecord.spfLookups.IPAddress|sort -Property {[system.version]($_ -replace "\/\d{1,3}$","")}
        #Proper but will need to update Resolve-SPFRecord
        #Too: https://learn.microsoft.com/dotnet/api/system.net.ipnetwork
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
        $testResultMarkdown = "Not all Exchange Online accepted domains designate Exchange Online as approved sender or, for a parked domain, fail all senders.`n`n%TestResult%"
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
