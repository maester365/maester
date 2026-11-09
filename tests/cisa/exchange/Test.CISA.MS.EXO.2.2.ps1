function Test-MtCisaSpfDirective {
    <#
    .SYNOPSIS
    Checks state of SPF records for all exo domains

    .DESCRIPTION
    An SPF policy SHALL be published for each sending domain, and fail or redirect non-approved senders.

    .EXAMPLE
    Test-MtCisaSpfDirective

    Returns true if each sending domain has an SPF fail-all mechanism or redirect modifier

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
    param()

    $acceptedDomains = Get-MtExo -Request AcceptedDomain
    $sendingDomains = $acceptedDomains | Where-Object {`
        -not $_.SendingFromDomainDisabled
    }

    $spfRecords = @()
    foreach($domain in $sendingDomains){
        $spfRecord = Get-MailAuthenticationRecord -DomainName $domain.DomainName -Records SPF
        $spfRecord | Add-Member -MemberType NoteProperty -Name "pass" -Value "Failed" -ErrorAction Ignore
        $spfRecord | Add-Member -MemberType NoteProperty -Name "reason" -Value "" -ErrorAction Ignore

        $terms = @($spfRecord.spfRecord.terms)
        $hasFailAll = @($terms | Where-Object {
            $_.mechanism -eq 'all' -and $_.qualifier -in @('-', '~')
        }).Count -gt 0
        $hasRedirect = @($terms | Where-Object { $_.modifier -eq 'redirect' }).Count -gt 0

        if ($domain.IsCoexistenceDomain) {
            $spfRecord.pass = "Skipped"
            $spfRecord.reason = "coexistence domain"
        }
        elseif ($hasFailAll -or $hasRedirect) {
            $spfRecord.pass = "Passed"
            $spfRecord.reason = if ($hasFailAll) { 'Fail-all mechanism' } else { 'Redirect modifier' }
        }
        elseif ($spfRecord.spfRecord -is [string] -and $spfRecord.spfRecord -like "*not available") {
            $spfRecord.pass = "Skipped"
            $spfRecord.reason = $spfRecord.spfRecord
        }
        elseif ($spfRecord.spfRecord -is [string]) {
            $spfRecord.reason = $spfRecord.spfRecord
        }
        else {
            $spfRecord.reason = "No -all, ~all, or redirect mechanism"
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
    }
    elseif ("Failed" -notin $spfRecords.pass -and "Passed" -notin $spfRecords.pass) {
        Add-MtTestResultDetail -SkippedBecause NotSupported
        return $null
    }
    else {
        $testResult = $true
    }

    if($testResult){
        $testResultMarkdown = "Well done. All sending domains have an SPF policy that fails or redirects non-approved senders.`n`n%TestResult%"
    }else{
        $testResultMarkdown = "One or more sending domains do not have an SPF policy that fails or redirects non-approved senders.`n`n%TestResult%"
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
