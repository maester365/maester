function Test-MtAdUserBuiltInAdminCount {
    <#
    .SYNOPSIS
    Counts built-in administrator style user accounts.

    .DESCRIPTION
    This test identifies built-in administrator style user objects by looking for
    the built-in administrator RID (`-500`) and critical system objects. Tracking
    these accounts helps defenders focus on highly sensitive identities that are
    commonly targeted during Active Directory compromise.

    .EXAMPLE
    Test-MtAdUserBuiltInAdminCount

    .LINK
    https://maester.dev/docs/commands/Test-MtAdUserBuiltInAdminCount
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $adState = Get-MtADDomainState
    if ($null -eq $adState) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "Not connected to Active Directory."
        return $null
    }

    $users = $adState.Users

    $builtInAdminUsers = @($users | Where-Object {
            $sidValue = [string]$_.SID
            $sidValue -match '-500$' -or $_.isCriticalSystemObject -eq $true
        })

    $totalCount = ($builtInAdminUsers | Measure-Object).Count
    $enabledCount = (@($builtInAdminUsers | Where-Object { $_.Enabled -eq $true }) | Measure-Object).Count
    $criticalCount = (@($builtInAdminUsers | Where-Object { $_.isCriticalSystemObject -eq $true }) | Measure-Object).Count
    $rid500Count = (@($builtInAdminUsers | Where-Object { ([string]$_.SID) -match '-500$' }) | Measure-Object).Count

    $testResult = $true

    $result = "| Metric | Value |`n"
    $result += "| --- | --- |`n"
    $result += "| Total Users Reviewed | $((@($users) | Measure-Object).Count) |`n"
    $result += "| Built-In Administrator Style Accounts | $totalCount |`n"
    $result += "| Enabled Built-In Administrator Style Accounts | $enabledCount |`n"
    $result += "| RID 500 Accounts | $rid500Count |`n"
    $result += "| Critical System Objects | $criticalCount |`n"

    $testResultMarkdown = "Active Directory built-in administrator style accounts were counted.`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}


