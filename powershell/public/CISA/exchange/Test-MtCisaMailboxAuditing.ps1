<#
.SYNOPSIS
    Checks state of mailbox auditing

.DESCRIPTION

    Mailbox auditing SHALL be enabled.

.EXAMPLE
    Test-MtCisaMailboxAuditing

    Returns true if mailbox auditing is enabled.
#>

Function Test-MtCisaMailboxAuditing {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $config = Get-OrganizationConfig

    $testResult = (-not $config.AuditDisabled)

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant has mailbox auditing enabled.`n`n%TestResult%"
        $result = "✅ Pass"
    } else {
        $testResultMarkdown = "Your tenant does not have mailbox auditing enabled.`n`n%TestResult%"
        $result = "❌ Fail"
    }

    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}