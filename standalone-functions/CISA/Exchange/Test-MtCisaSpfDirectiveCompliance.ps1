function Test-MtCisaSpfDirectiveCompliance {
    <#
    .SYNOPSIS
    Checks state of SPF records for all exo domains

    .DESCRIPTION
    An SPF policy SHALL be published for each domain, designating only these addresses as approved senders.
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtCisaSpfDirectiveCompliance
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
    $sendingDomains = $acceptedDomains | Where-Object {`
        -not $_.SendingFromDomainDisabled
    }

    $spfRecords = @()
    foreach($domain in $sendingDomains){
        $spfRecord = Get-MailAuthenticationRecord -DomainName $domain.DomainName -Records SPF
        $spfRecord | Add-Member -MemberType NoteProperty -Name "pass" -Value "Failed" -ErrorAction Ignore
        $spfRecord | Add-Member -MemberType NoteProperty -Name "reason" -Value "" -ErrorAction Ignore

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
        #Too: https://learn.microsoft.com/en-us/dotnet/api/system.net.ipnetwork
        #[ipaddress]::HostToNetworkOrder(([ipaddress]$_).address)

        $spfRecords += $spfRecord
    }

    if("Failed" -in $spfRecords.pass){
        $testResult = $false
    }elseif("Failed" -notin $spfRecords.pass -and "Passed" -notin $spfRecords.pass){
        return $null
    }else{
        $testResult = $true
    }
    $passResult = "✅ Pass"
    $failResult = "❌ Fail"
    $skipResult = "🗄️ Skip"
    $result = "| Domain | Result | Reason | Directives |`n"
    $result += "| --- | --- | --- | --- |`n"
    foreach ($item in $spfRecords | Sort-Object -Property domain) {
        switch($item.pass){
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
    }


    return $testResult

}
