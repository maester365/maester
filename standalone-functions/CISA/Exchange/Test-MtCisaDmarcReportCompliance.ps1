function Test-MtCisaDmarcReportCompliance {
    <#
    .SYNOPSIS
    Checks state of DMARC records for all exo domains

    .DESCRIPTION
    An agency point of contact SHOULD be included for aggregate and failure reports.
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtCisaDmarcReportCompliance
    if ($result -eq $true) { Write-Host "Compliant" }
    elseif ($result -eq $false) { Write-Host "Non-Compliant" }
    else { Write-Host "Skipped or Error" }

    .OUTPUTS
    bool|null - Returns true if compliant, false if non-compliant, null if skipped or error
    #>
    [CmdletBinding()]
    [OutputType([bool], [nullable])]
    param()

    # Phase 1: Prerequisites Check
    try {
        $exoSession = Get-PSSession | Where-Object { $_.ConfigurationName -eq 'Microsoft.Exchange' -and $_.State -eq 'Opened' }
        if ($null -eq $exoSession) {
            Write-Verbose "Not connected to Exchange Online"
            return $null
        }
    } catch {
        Write-Verbose "Exchange Online connection check failed: $_"
        return $null
    }

    # Phase 2: Data Collection & Phase 3: Compliance Validation

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
        $matchDomain = "(?:^|\.)(?'second'[\w-]+\.[\w-]+$)"
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
        return $null
    }else{
        $testResult = $true
    }
    $passResult = "✅ Pass"
    $failResult = "❌ Fail"
    $result = "| Domain | Result | Reason | Targets |`n"
    $result += "| --- | --- | --- | --- |`n"
    foreach ($item in $dmarcRecords | Sort-Object -Property domain) {
        switch($item.pass){
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

    }


    return $testResult

}
