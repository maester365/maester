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

    if (-not (Test-MtConnection ExchangeOnline)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedExchange
        return $null
    }
    $return = $true
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
}