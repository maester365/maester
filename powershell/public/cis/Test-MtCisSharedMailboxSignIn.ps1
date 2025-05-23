<#
.SYNOPSIS
    Checks if shared mailboxes allow sign-ins

.DESCRIPTION
    Ensure Sign ins are blocked for shared mailboxes.
    CIS Microsoft 365 Foundations Benchmark v4.0.0

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
    $sharedMailboxes = Get-MtExo -Request EXOMailbox -ErrorAction Stop | Where-Object { $_.RecipientTypeDetails -eq "SharedMailbox" }

    if (($sharedMailboxes | Measure-Object).Count -eq 0) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "There are no SharedMailbox in your Tenant."
        return $null
    }

    Write-Verbose "For each mailbox get mailbox and AccountEnabled status"
    $mailboxDetails = @()
    foreach ($mbx in $sharedMailboxes) {
        $mgUser = Get-MgUser -UserId $mbx.ExternalDirectoryObjectId -Property DisplayName, UserPrincipalName, AccountEnabled
        $mailboxDetails += [pscustomobject]@{
            DisplayName       = $mgUser.DisplayName
            UserPrincipalName = $mgUser.UserPrincipalName
            AccountEnabled    = $mgUser.AccountEnabled
        }
    }

    Write-Verbose "Select shared mailboxes where sign-in is enabled"
    $result = $mailboxDetails | Where-Object { $_.AccountEnabled -eq "True" }
    $resultCount = ($result | Measure-Object).Count

    $testResult = if ($resultCount -eq 0) { $true } else { $false }

    if ($testResult) {
        $testResultMarkdown = "Well done. Your tenant has no shared mailboxes with sign-in enabled:`n`n%TestResult%"
    }
    else {
        $testResultMarkdown = "Your tenant has $(($result | Measure-Object).Count) shared mailboxes with sign-in enabled:`n`n%TestResult%"
    }



    $resultMd = "| Shared Mailbox | Sign-in Disabled |`n"
    $resultMd += "| --- | --- |`n"
    foreach ($item in $result | Sort-Object @sortSplat) {
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