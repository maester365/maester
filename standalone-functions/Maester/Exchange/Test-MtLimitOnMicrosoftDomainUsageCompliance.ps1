function Test-MtLimitOnMicrosoftDomainUsageCompliance {
    <#
    .SYNOPSIS
    Ensure mailboxes do not use the .onmicrosoft.com domain as primary SMTP address

    .DESCRIPTION
    This test checks if any mailbox is using the .onmicrosoft.com domain as primary SMTP address.
    Usage of the .onmicrosoft.com domain has its limitation and receives throttling.
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtLimitOnMicrosoftDomainUsageCompliance
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

    $return = $true
    if ($checkType -eq "DefenderXDR") {
        Write-Verbose "Checking if mailboxes send outbound mails using the .onmicrosoft.com domain..."
        try {
            $outboundTreshold = 100
            $timespan = 14
            $timespanISO6801 = "P$($timespan)D"

            $query = "EmailEvents | where EmailDirection == 'Outbound' | where SenderMailFromDomain endswith '.onmicrosoft.com' | extend Day = startofday(Timestamp) | summarize count() by SenderMailFromDomain, Day | where count_ >= $($outboundTreshold)"
            $KqlEmailEvents = Invoke-MtGraphSecurityQuery -Query $query -Timespan $timespanISO6801

            if (($KqlEmailEvents | Measure-Object).Count -eq 0) {
                $result = "Well done. No more then $($outboundTreshold) outbound mails has been send in the last $($timespan) days using the .onmicrosoft.com domain."
            } else {
                $resultTable = "| SenderMailFromDomain | onDay | Count |`n"
                $resultTable += "| --- | --- | --- |`n"
                foreach ($item in $KqlEmailEvents) {
                    $resultTable += "| $($item.SenderMailFromDomain) | $((Get-Date($item.Day)).ToString("dd.MM.yyyy")) | $($item.count_) |`n"
                }
                $return = $false
            }
            return $return
        } catch {
            return $null
        }
    } elseif ($checkType -eq "ExchangeOnline") {
        Write-Verbose "Checking if mailboxes use the .onmicrosoft.com domain as primary SMTP address..."
        try {
            $allMbx = Get-Mailbox | Where-Object { $_.PrimarySmtpAddress -like "*@*.onmicrosoft.com" }
            if (($allMbx | Measure-Object).Count -eq 0) {
                $result = "Well done. No mailbox uses the .onmicrosoft.com domain as primary SMTP address."
            } else {
                $mgUsers = @()
                foreach ($mbx in $allMbx) {
                    $mgUsers += Invoke-MgGraphRequest -Uri 'https://graph.microsoft.com/v1.0/users' -UniqueId $mbx.ExternalDirectoryObjectId
                }
                $return = $false
            }
            return $return
        } catch {
            return $null
        }
    } else {
        return $null
    }

}
