<#
.SYNOPSIS
    Checks if shared mailboxes allow sign-ins

.DESCRIPTION
    Ensure Sign ins are blocked for shared mailboxes.
    CIS Microsoft 365 Foundations Benchmark v3.1.0

.EXAMPLE
    Test-MtCisSharedMailboxSignIn

    Returns true if no shared mailboxes allow sign-ins

.LINK
    https://maester.dev/docs/commands/Test-MtCisSharedMailboxSignIn
#>
function Test-MtCisSharedMailboxSignIn {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if (!(Test-MtConnection ExchangeOnline)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedExchange
        return $null
    }

    if (!(Test-MtConnection Graph)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedGraph
        return $null
    }

    Write-Verbose "Getting all shared mailboxes"
    $sharedMailboxes = Get-MtExo -Request EXOMailbox | Where-Object { $_.RecipientTypeDetails -eq "SharedMailbox" }

    Write-Verbose "For each mailbox get mailbox an and AccountEnabled status"
    $mailboxDetails = @()
    $mailboxDetails += $sharedMailboxes | ForEach-Object {
        Get-MgUser -UserId $_.ExternalDirectoryObjectId -Property DisplayName, UserPrincipalName, AccountEnabled }


    Write-Verbose "Select shared mailboxes where sign-in is enabled"
    $result = $mailboxDetails | Where-Object { $_.AccountEnabled -eq "True" }

    $testResult = ($result | Measure-Object).Count -eq 0

    $sortSplat = @{
        Property = @(
            @{
                Expression = "AccountEnabled"
                Descending = "True"
            },
            @{
                Expression = "DisplayName"
            }
        )
    }

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant has no shared mailboxes with sign-in enabled:`n`n%TestResult%"
    }
    else {
        $testResultMarkdown = "Your tenant has 1 or more shared mailboxes with sign-in enabled:`n`n%TestResult%"
    }

    $resultMd = "| Display Name | Shared Mailbox |`n"
    $resultMd += "| --- | --- |`n"
    foreach ($item in $mailboxDetails | Sort-Object @sortSplat) {
        $itemResult = "❌ Fail"
        if ($item.id -notin $result.id) {
            $itemResult = "✅ Pass"
        }
        $resultMd += "| $($item.displayName) | $($itemResult) |`n"
    }

    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $resultMd

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
