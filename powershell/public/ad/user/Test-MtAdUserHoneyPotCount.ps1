function Test-MtAdUserHoneyPotCount {
    <#
    .SYNOPSIS
    Counts potential honey pot style user accounts.

    .DESCRIPTION
    This test identifies user accounts with names that may be intentionally
    attractive to attackers, such as accounts containing terms like admin,
    root, test, backup, or sql. These names can indicate decoy accounts,
    monitoring traps, or simply risky naming patterns that deserve review.

    .EXAMPLE
    Test-MtAdUserHoneyPotCount

    .LINK
    https://maester.dev/docs/commands/Test-MtAdUserHoneyPotCount
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

    $honeyPotPatterns = @(
        @{ Name = 'admin'; Regex = '(^|[-_.])(admin|administrator)([-_.]|$)' },
        @{ Name = 'root'; Regex = '(^|[-_.])root([-_.]|$)' },
        @{ Name = 'test'; Regex = '(^|[-_.])(test|temp)([-_.]|$)' },
        @{ Name = 'backup'; Regex = '(^|[-_.])backup([-_.]|$)' },
        @{ Name = 'sql'; Regex = '(^|[-_.])(sql|dba|oracle)([-_.]|$)' }
    )

    $potentialHoneyPots = foreach ($user in $users) {
        $sidValue = [string]$user.SID
        if ($sidValue -match '-500$|-(501|502)$' -or $user.isCriticalSystemObject -eq $true) {
            continue
        }

        $candidateValues = @($user.SamAccountName, $user.Name) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        $matchesFound = foreach ($pattern in $honeyPotPatterns) {
            if ($candidateValues | Where-Object { $_ -match $pattern.Regex }) {
                $pattern
            }
        }
        if ($matchesFound.Count -gt 0) {
            [PSCustomObject]@{
                SamAccountName = $user.SamAccountName
                Name           = $user.Name
                Enabled        = $user.Enabled
                MatchCount     = $matchesFound.Count
                MatchTypes     = ($matchesFound.Name -join ', ')
            }
        }
    }

    $potentialHoneyPots = @($potentialHoneyPots | Sort-Object SamAccountName -Unique)
    $totalCount = ($potentialHoneyPots | Measure-Object).Count
    $enabledCount = (@($potentialHoneyPots | Where-Object { $_.Enabled -eq $true }) | Measure-Object).Count

    $testResult = $true

    $result = "| Metric | Value |`n"
    $result += "| --- | --- |`n"
    $result += "| Total Users Reviewed | $((@($users) | Measure-Object).Count) |`n"
    $result += "| Potential Honey Pot Users | $totalCount |`n"
    $result += "| Enabled Potential Honey Pot Users | $enabledCount |`n"

    $testResultMarkdown = "Active Directory users were reviewed for potential honey pot naming patterns.`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}


