function Test-MtCisSharedMailboxSignIn {
    <#
    .SYNOPSIS
    Checks if shared mailboxes allow sign-ins

    .DESCRIPTION
    Ensure Sign ins are blocked for shared mailboxes.
    CIS Microsoft 365 Foundations Benchmark v7.0.0 (1.2.2, L1)

    .EXAMPLE
    Test-MtCisSharedMailboxSignIn

    Returns true if no shared mailboxes allow sign-ins

    .LINK
    https://maester.dev/docs/commands/Test-MtCisSharedMailboxSignIn
    #>
    [MaesterTest(
        Id = 'CIS.M365.1.2.2',
        Title = 'Ensure sign-in to shared mailboxes is blocked',
        Severity = 'High',
        Category = 'CIS',
        Product = 'Microsoft 365',
        Tag = ('CIS E3', 'CIS E3 Level 1', 'CIS M365 v7.0.0', 'L1'),
        Service = ('ExchangeOnline', 'Graph'),
        Author = 'NZLostboy',
        Contributor = ('HenrikPiecha', 'thomas-s-schmidt', 'ricmestre', 'Mynster9361')
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Getting all shared mailboxes'
    $sharedMailboxes = Get-MtExo -Request EXOSharedMailbox -ErrorAction Stop

if (($sharedMailboxes | Measure-Object).Count -eq 0) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'There are no shared mailboxes in your tenant.'
        return $null
    }

    Write-Verbose 'For each mailbox get mailbox and AccountEnabled status'
    $mgUsers = Invoke-MtGraphRequest -RelativeUri "users" -UniqueId @($sharedMailboxes.ExternalDirectoryObjectId) -Select id, displayName, userPrincipalName, accountEnabled
    $mailboxDetails = foreach ($mgUser in $mgUsers) {
        $mgUser | Select-Object DisplayName, UserPrincipalName, AccountEnabled
    }

    Write-Verbose 'Select shared mailboxes where sign-in is enabled'
    $result = $mailboxDetails | Where-Object { $_.AccountEnabled -eq 'True' }
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
        $itemResult = '❌ Fail'
        if ($item.id -notin $result.id) {
            $itemResult = '✅ Pass'
        }
        $resultMd += "| $(Get-MtSafeMarkdown $item.displayName) | $($itemResult) |`n"
    }
    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $resultMd

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
