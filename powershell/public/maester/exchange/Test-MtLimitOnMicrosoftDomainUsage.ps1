<#
.SYNOPSIS
    Ensure mailboxes do not use the .onmicrosoft.com domain as primary SMTP address

.DESCRIPTION
    This test checks if any mailbox is using the .onmicrosoft.com domain as primary SMTP address.
    Usage of the .onmicrosoft.com domain has its limitation and receives throttling.

.EXAMPLE
    Test-MtLimitOnMicrosoftDomainUsage

    Returns true if no mailbox is using the .onmicrosoft.com domain as primary SMTP address

.LINK
    https://maester.dev/docs/commands/Test-MtLimitOnMicrosoftDomainUsage
#>
function Test-MtLimitOnMicrosoftDomainUsage {
    [CmdletBinding()]
    [OutputType([bool])]
    param()


    if ( ( Get-MtLicenseInformation DefenderXDR ) -ne "DefenderXDR" ) {
        # Add-MtTestResultDetail -SkippedBecause NotLicensedDefenderXDR
        # return $null
        if (-not (Test-MtConnection ExchangeOnline)) {
            Add-MtTestResultDetail -SkippedBecause NotConnectedExchange
            return $null
        } else {
            $checkType = "ExchangeOnline"
        }
    } else {
        $checkType = "DefenderXDR"
    }

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
                Add-MtTestResultDetail -Result $result
            } else {
                $result = "In the last $($timespan) days your tenant send on atleast one day more then $($outboundTreshold) outbound mails using the .onmicrosoft.com domain:`n`n%TestResult%"
                $resultTable = "| SenderMailFromDomain | onDay | Count |`n"
                $resultTable += "| --- | --- | --- |`n"
                foreach ($item in $KqlEmailEvents) {
                    $resultTable += "| $($item.SenderMailFromDomain) | $((Get-Date($item.Day)).ToString("dd.MM.yyyy")) | $($item.count_) |`n"
                }
                $result = $result -replace '%TestResult%', $resultTable
                Add-MtTestResultDetail -Result $result
                $return = $false
            }
            return $return
        } catch {
            Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
            return $null
        }
    } elseif ($checkType -eq "ExchangeOnline") {
        Write-Verbose "Checking if mailboxes use the .onmicrosoft.com domain as primary SMTP address..."
        try {
            $allMbx = Get-Mailbox | Where-Object { $_.PrimarySmtpAddress -like "*@*.onmicrosoft.com" }
            if (($allMbx | Measure-Object).Count -eq 0) {
                $result = "Well done. No mailbox uses the .onmicrosoft.com domain as primary SMTP address."
                Add-MtTestResultDetail -Result $result
            } else {
                $mgUsers = @()
                foreach ($mbx in $allMbx) {
                    $mgUsers += Invoke-MtGraphRequest -RelativeUri "users" -UniqueId $mbx.ExternalDirectoryObjectId
                }
                $result = "Your tenant has $(($allMbx | Measure-Object).Count) mailboxes using the .onmicrosoft.com domain as primary SMTP address:`n`n%TestResult%"
                $return = $false
                Add-MtTestResultDetail -Result $result -GraphObjects $mgUsers -GraphObjectType Users
            }
            return $return
        } catch {
            Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
            return $null
        }
    } else {
        Add-MtTestResultDetail -SkippedBecause NotSupported
        return $null
    }
}