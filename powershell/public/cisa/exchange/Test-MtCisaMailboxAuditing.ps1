<#
.SYNOPSIS
    Checks state of mailbox auditing

.DESCRIPTION
    Mailbox auditing SHALL be enabled.

.EXAMPLE
    Test-MtCisaMailboxAuditing

    Returns true if mailbox auditing is enabled.

.LINK
    https://maester.dev/docs/commands/Test-MtCisaMailboxAuditing
#>
function Test-MtCisaMailboxAuditing {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if(!(Test-MtConnection ExchangeOnline)){
        Add-MtTestResultDetail -SkippedBecause NotConnectedExchange
        return $null
    }

    $config = Get-MtExo -Request OrganizationConfig

    $testResult = (-not $config.AuditDisabled)

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant has mailbox auditing enabled.`n`n%testResult%"
        $result = "✅ Pass"
    } else {
        $testResultMarkdown = "Your tenant does not have mailbox auditing enabled.`n`n%testResult%"
        $result = "❌ Fail"
    }

    $testResultMarkdown = $testResultMarkdown -replace "%testResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}