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

    if (!(Test-MtConnection ExchangeOnline)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedExchange
        return $null
    }

    try {
        $dkimSigningConfigs = Get-MtExo -Request DkimSigningConfig
        $acceptedDomains = Get-MtExo -Request AcceptedDomain
        <# DKIM record without key for parked domains
        $sendingDomains = $acceptedDomains | Where-Object {`
            -not $_.SendingFromDomainDisabled
        }
        #>

        $dkimRecords = @()
        foreach ($domain in $acceptedDomains) {
            $dkimSigningConfig = $dkimSigningConfigs | Where-Object {`
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
            $dkimDnsName = if ($isMicrosoftDomain) {
                $dkimSigningConfig."$($selector)CNAME"
            } else {
                "$($Selector)._domainkey.$($domain.DomainName)"
            }
            $dkimRecord = Get-MailAuthenticationRecord -DomainName $domain.DomainName -DkimDnsName $dkimDnsName -Records DKIM
            $dkimRecord | Add-Member -MemberType NoteProperty -Name "pass" -Value "Failed"
            $dkimRecord | Add-Member -MemberType NoteProperty -Name "reason" -Value ""

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
            } elseif ($dkimRecord.dkimRecord -like "*not available") {
                $dkimRecord.pass = "Skipped"
                $dkimRecord.reason = $dkimRecord.dkimRecord
            } else {
                $dkimRecord.reason = $dkimRecord.dkimRecord
            }

            $dkimRecords += $dkimRecord
        }
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }

    if ("Failed" -in $dkimRecords.pass) {
        $testResult = $false
    } elseif ("Failed" -notin $dkimRecords.pass -and "Passed" -notin $dkimRecords.pass) {
        Add-MtTestResultDetail -SkippedBecause NotSupported
        return $null
    } else {
        $testResult = $true
    }

    $portalLink = "https://security.microsoft.com/authentication?viewid=DKIM"

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant's domains have DKIM configured and valid records exist.`n`n%TestResult%"
    } else {
        $testResultMarkdown = "Your tenant's domains do not have DKIM fully deployed. Review [EXO configuration]($portalLink) and DNS records.`n`n%TestResult%"
    }

    $passResult = "✅ Pass"
    $failResult = "❌ Fail"
    $skipResult = "🗄️ Skip"
    $result = "| Domain | Result | Reason |`n"
    $result += "| --- | --- | --- |`n"
    foreach ($item in $dkimRecords | Sort-Object -Property domain) {
        switch ($item.pass) {
            "Passed" { $itemResult = $passResult }
            "Skipped" { $itemResult = $skipResult }
            "Failed" { $itemResult = $failResult }
        }
        $result += "| $($item.domain) | $($itemResult) | $($item.reason) |`n"
    }

    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}