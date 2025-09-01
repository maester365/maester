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
}