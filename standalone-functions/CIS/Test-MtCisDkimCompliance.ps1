function Test-MtCisDkimCompliance {
    <#
    .SYNOPSIS
    Checks state of DKIM for all EXO domains

    .DESCRIPTION
    DKIM SHOULD be enabled for all domains.
    CIS Microsoft 365 Foundations Benchmark v6.0.1
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtCisDkimCompliance
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

    try {
        $dkimSigningConfigs = Get-DkimSigningConfig
        $acceptedDomains = Get-AcceptedDomain
        <# DKIM record without key for parked domains
        $sendingDomains = $acceptedDomains | Where-Object {
            -not $_.SendingFromDomainDisabled
        }
        #>

        $dkimRecords = @()
        foreach ($domain in $acceptedDomains) {
            $dkimSigningConfig = $dkimSigningConfigs | Where-Object {
                $_.domain -eq $domain.domainname
            }

            if ((Get-Date) -gt $dkimSigningConfig.RotateOnDate) {
                if ($Selector -ne $dkimSigningConfig.SelectorAfterRotateOnDate) {
                    Write-Verbose "Using DKIM $($dkimSigningConfig.SelectorAfterRotateOnDate) based on EXO config"
                }
                $Selector = $dkimSigningConfig.SelectorAfterRotateOnDate
            } else {
                if ($Selector -ne $dkimSigningConfig.SelectorBeforeRotateOnDate) {
                    Write-Verbose "Using DKIM $($dkimSigningConfig.SelectorBeforeRotateOnDate) based on EXO config"
                }
                $selector = $dkimSigningConfig.SelectorBeforeRotateOnDate
            }

            $isMicrosoftDomain = $domain.DomainName.EndsWith(".onmicrosoft.com")
            $isMicrosoftExoHybridDomain = $domain.DomainName.EndsWith(".mail.onmicrosoft.com")
            $dkimDnsName = if ($isMicrosoftExoHybridDomain) {
                "$($Selector)._domainkey.$($domain.DomainName)"
            } elseif ($isMicrosoftDomain) {
                $dkimSigningConfig."$($selector)CNAME"
            } else {
                "$($Selector)._domainkey.$($domain.DomainName)"
            }
            $dkimRecord = Get-MailAuthenticationRecord -DomainName $domain.DomainName -DkimDnsName $dkimDnsName -Records DKIM
            $dkimRecord | Add-Member -MemberType NoteProperty -Name 'pass' -Value 'Failed'
            $dkimRecord | Add-Member -MemberType NoteProperty -Name 'reason' -Value ''

            if ($domain.SendingFromDomainDisabled) {
                $dkimRecord.pass = 'Skipped'
                $dkimRecord.reason = 'Parked domain'
            } elseif (-not $dkimSigningConfig.enabled) {
                $dkimRecord.pass = 'Failed'
                $dkimRecord.reason = 'DKIM is disabled'
            } elseif ($dkimRecord.dkimRecord.GetType().Name -eq 'DKIMRecord') {
                if (-not $dkimRecord.dkimRecord.validBase64) {
                    $dkimRecord.reason = 'Malformed public key'
                } else {
                    $dkimRecord.pass = 'Passed'
                }
            } elseif ($domain.DomainName -like '*.onmicrosoft.com') {
                $dkimRecord.reason = "Recommendation: Disable sending from domain"
            } elseif ($dkimRecord.dkimRecord -like '*not available') {
                $dkimRecord.pass = 'Skipped'
                $dkimRecord.reason = $dkimRecord.dkimRecord
            } else {
                $dkimRecord.reason = $dkimRecord.dkimRecord
            }

            $dkimRecords += $dkimRecord
        }
    } catch {
        return $null
    }

    if ('Failed' -in $dkimRecords.pass) {
        $testResult = $false
    } elseif ('Failed' -notin $dkimRecords.pass -and 'Passed' -notin $dkimRecords.pass) {
        return $null
    } else {
        $testResult = $true
    }

    try {
        $passResult = '✅ Pass'
        $failResult = '❌ Fail'
        $skipResult = '🗄️ Skip'
        $result = "| Domain | Result | Reason |`n"
        $result += "| --- | --- | --- |`n"
        foreach ($item in $dkimRecords | Sort-Object -Property domain) {
            switch ($item.pass) {
            }
        }


        return $testResult
    } catch {
        return $null
    }

}
