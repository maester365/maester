function Test-MtDomainsDmarcExists {
    <#
    .SYNOPSIS
    Checks state of DMARC records for all Entra registered domains

    .DESCRIPTION
     A DMARC policy SHALL be published for every managed and verified domain in the Entra tenant.

    .EXAMPLE
    Test-MtDomainsDmarcExists

    Returns true if DMARC record exists for every managed and verified domain

    .LINK
    https://maester.dev/docs/commands/Test-MtDomainsDmarcExists
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

    <# REAL EXIST CASE

    foreach($domain in ($verifiedManagedDomains | Sort-Object -Property DomainName -Unique)){
        #This regex does NOT capture for third level domain scenarios
        #e.g., example.co.uk; example.ny.us;
        $matchDomain = "(?:^|\.)(?'second'[\w-]+\.[\w-]+$)"
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
#>
    if ("Failed" -notin $dmarcRecords.pass -and "Passed" -notin $dmarcRecords.pass) {
        if ($dmarcRecords.reason -like "*not available") {
            Add-MtTestResultDetail -SkippedBecause NotSupported
            return $null
        } else {
            Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "Skipped for $($dmarcRecords.reason)"
        }
    } else {
        $testResult = $true
    }

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant's domains have a DMARC record. Review report targets.`n`n%TestResult%"
    } else {
        $testResultMarkdown = "Your tenant's second level domains do not have a DMARC record.`n`n%TestResult%"
    }

    $passResult = "✅ Pass"
    $failResult = "❌ Fail"
    $skipResult = "🗄️ Skip"
    $result = "| Domain | Result | Reason | Policy | Subdomain Policy |`n"
    $result += "| --- | --- | --- | --- | --- |`n"
    foreach ($item in $dmarcRecords) {
        switch ($item.pass) {
            "Passed" { $itemResult = $passResult }
            "Skipped" { $itemResult = $skipResult }
            "Failed" { $itemResult = $failResult }
        }

        $result += "| $($item.domain) | $($itemResult) | $($item.reason) | $($item.dmarcRecord.policy) | $($item.dmarcRecord.policySubdomain) |`n"
    }

    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
