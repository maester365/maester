<#
.SYNOPSIS
    Checks state of DKIM for all EXO domains

.DESCRIPTION
    DKIM SHOULD be enabled for all domains.

.EXAMPLE
    Test-MtCisaDkim

    Returns true if DKIM record exists and EXO shows DKIM enabled

.LINK
    https://maester.dev/docs/commands/Test-MtCisaDkim
#>
function Test-MtCisaDkim {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # Selector-name for the DKIM record to test..
        [string]$Selector = "selector1"
    )

    if(!(Test-MtConnection ExchangeOnline)){
        Add-MtTestResultDetail -SkippedBecause NotConnectedExchange
        return $null
    }

    $signingConfig = Get-MtExo -Request DkimSigningConfig
    $acceptedDomains = Get-MtExo -Request AcceptedDomain
    <# DKIM record without key for parked domains
    $sendingDomains = $acceptedDomains | Where-Object {`
        -not $_.SendingFromDomainDisabled
    }
    #>

    $dkimRecords = @()
    foreach($domain in $acceptedDomains){
        $config = $signingConfig | Where-Object {`
            $_.domain -eq $domain.domainname
        }
        if((Get-Date) -gt $config.RotateOnDate){
            if($Selector -ne $config.SelectorAfterRotateOnDate){
                Write-Warning "Using DKIM $($config.SelectorAfterRotateOnDate) based on EXO config"
            }
            $Selector = $config.SelectorAfterRotateOnDate
        }else{
            if($Selector -ne $config.SelectorBeforeRotateOnDate){
                Write-Warning "Using DKIM $($config.SelectorBeforeRotateOnDate) based on EXO config"
            }
            $selector = $config.SelectorBeforeRotateOnDate
        }

        $dkimRecord = Get-MailAuthenticationRecord -DomainName $domain.DomainName -DkimSelector $Selector -Records DKIM
        $dkimRecord | Add-Member -MemberType NoteProperty -Name "pass" -Value "Failed"
        $dkimRecord | Add-Member -MemberType NoteProperty -Name "reason" -Value ""

        if($dkimRecord.dkimRecord.GetType().Name -eq "DKIMRecord"){
            if($config.enabled){
                if(-not $dkimRecord.dkimRecord.validBase64){
                    $dkimRecord.reason = "Malformed public key"
                }else{
                    $dkimRecord.pass = "Passed"
                }
            }else{
                $dkimRecord.pass = "Skipped"
                $dkimRecord.reason = "Parked domain"
            }
        }elseif($dkimRecord.dkimRecord -like "*not available"){
            $dkimRecord.pass = "Skipped"
            $dkimRecord.reason = $dkimRecord.dkimRecord
        }else{
            $dkimRecord.reason = $dkimRecord.dkimRecord
        }

        $dkimRecords += $dkimRecord
    }

    if("Failed" -in $dkimRecords.pass){
        $testResult = $false
    }elseif("Failed" -notin $dkimRecords.pass -and "Passed" -notin $dkimRecords.pass){
        Add-MtTestResultDetail -SkippedBecause NotSupported
        return $null
    }else{
        $testResult = $true
    }

    $portalLink = "https://security.microsoft.com/authentication?viewid=DKIM"

    if($testResult){
        $testResultMarkdown = "Well done. Your tenant's domains have DKIM configured and valid records exist.`n`n%TestResult%"
    }else{
        $testResultMarkdown = "Your tenant's domains do not have DKIM fully deployed. Review [EXO configuration]($portalLink) and DNS records.`n`n%TestResult%"
    }

    $passResult = "✅ Pass"
    $failResult = "❌ Fail"
    $skipResult = "🗄️ Skip"
    $result = "| Domain | Result | Reason |`n"
    $result += "| --- | --- | --- |`n"
    foreach ($item in $dkimRecords | Sort-Object -Property domain) {
        switch($item.pass){
            "Passed" {$itemResult = $passResult}
            "Skipped" {$itemResult = $skipResult}
            "Failed" {$itemResult = $failResult}
        }
        $result += "| $($item.domain) | $($itemResult) | $($item.reason) |`n"
    }

    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}