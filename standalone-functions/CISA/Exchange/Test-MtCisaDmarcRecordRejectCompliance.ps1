function Test-MtCisaDmarcRecordRejectCompliance {
    <#
    .SYNOPSIS
    Checks state of DMARC records for all exo domains

    .DESCRIPTION
    The DMARC message rejection option SHALL be p=reject.
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtCisaDmarcRecordRejectCompliance
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
        # If it's the coexistence domain (contoso.mail.onmicrosoft.com), skip the 2nd level check.
        # If it's the initial domain (contoso.onmicrosoft.com), skip the 2nd level check. We cannot manage onmicrosoft.com.
        if ($domain.IsCoexistenceDomain -or $domain.InitialDomain) {
            $expandedDomains += [PSCustomObject]@{
                DomainName = $domain.DomainName
                IsCoexistenceDomain = $domain.IsCoexistenceDomain
            }
            continue
        }

        #This regex does NOT capture for third level domain scenarios
        #e.g., example.co.uk; example.ny.us;
        $matchDomain = "(?:^|\.)(?'second'[\w-]+\.[\w-]+$)"
        $dmarcMatch = $domain.domainname -match $matchDomain
        if($dmarcMatch){
            $expandedDomains += [PSCustomObject]@{
                DomainName = $Matches.second
                IsCoexistenceDomain = $domain.IsCoexistenceDomain
            }
            if($domain.domainname -ne $Matches.second){
                $expandedDomains += [PSCustomObject]@{
                    DomainName = $domain.domainname
                    IsCoexistenceDomain = $domain.IsCoexistenceDomain
                }
            }
        }else{
            $expandedDomains += [PSCustomObject]@{
                DomainName = $domain.domainname
                IsCoexistenceDomain = $domain.IsCoexistenceDomain
            }
        }
    }

    # Sort and remove duplicate Domains
    $expandedDomains = $expandedDomains |  Sort-Object DomainName, IsCoexistenceDomain -Unique

    $dmarcRecords = @()
    foreach($domain in ($expandedDomains | Sort-Object -Unique)){
        $dmarcRecord = Get-MailAuthenticationRecord -DomainName $domain.DomainName -Records DMARC
        $dmarcRecord | Add-Member -MemberType NoteProperty -Name "pass" -Value "Failed"
        $dmarcRecord | Add-Member -MemberType NoteProperty -Name "reason" -Value ""

        $checkType = $dmarcRecord.dmarcRecord.GetType().Name -eq "DMARCRecord"

        if($domain.IsCoexistenceDomain){
            $dmarcRecord.pass = "Skipped"
            $dmarcRecord.reason = "Not applicable for coexistence domain"
        }elseif($checkType -and $dmarcRecord.dmarcRecord.policy -eq "reject"){
            $dmarcRecord.pass = "Passed"
        }elseif($checkType -and $dmarcRecord.dmarcRecord.policy -ne "reject"){
            $dmarcRecord.reason = "Policy is not reject"
        }elseif($checkType -and $dmarcRecord.dmarcRecord.policySubdomain -in @("none","quarantine")){
            $dmarcRecord.reason = "Subdomain policy is not reject"
        }elseif($dmarcRecord.dmarcRecord -like "*not available"){
            $dmarcRecord.pass = "Skipped"
            $dmarcRecord.reason = $dmarcRecord.dmarcRecord
        }elseif($domain -eq 'onmicrosoft.com' -or $domain -like '*.mail.onmicrosoft.com'){
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
        return $null
    }else{
        $testResult = $true
    }
    $passResult = "✅ Pass"
    $failResult = "❌ Fail"
    $skipResult = "🗄️ Skip"
    $result = "| Domain | Result | Reason | Policy | Subdomain Policy |`n"
    $result += "| --- | --- | --- | --- | --- |`n"
    foreach ($item in $dmarcRecords) {
        switch($item.pass){
        }

    }


    return $testResult

}
