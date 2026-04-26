function Test-MtAdUserHoneyPotDetails {
    <#
    .SYNOPSIS
    Returns details for potential honey pot style user accounts.

    .DESCRIPTION
    This test lists non-system users whose names contain terms that may attract
    attackers. The output helps teams validate whether those accounts are true
    deception assets, old test users, or risky naming artifacts.

    .EXAMPLE
    Test-MtAdUserHoneyPotDetails

    .LINK
    https://maester.dev/docs/commands/Test-MtAdUserHoneyPotDetails
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Starting Test-MtAdUserHoneyPotDetails"
    $adState = Get-MtADDomainState
    Write-Verbose "Retrieved AD state"
    if ($null -eq $adState) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "Not connected to Active Directory."
        return $null
    }
    Write-Verbose "Filtering/counting user honey pot details"

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
                SamAccountName       = $user.SamAccountName
                Name                 = $user.Name
                Enabled              = $user.Enabled
                MatchTypes           = ($matchesFound.Name -join ', ')
                LastLogonDate        = if ($null -ne $user.LastLogonDate) { Get-Date $user.LastLogonDate -Format 'yyyy-MM-dd HH:mm:ss' } else { 'Never/Unknown' }
                PasswordNeverExpires = $user.PasswordNeverExpires
                DistinguishedName    = $user.DistinguishedName
            }
        }
    }

    $potentialHoneyPots = @($potentialHoneyPots | Sort-Object SamAccountName -Unique)

    $testResult = $true

    $result = "| Metric | Value |`n"
    $result += "| --- | --- |`n"
    $result += "| Potential Honey Pot Users | $(($potentialHoneyPots | Measure-Object).Count) |`n`n"

    if ($potentialHoneyPots.Count -gt 0) {
        $result += "### Potential Honey Pot User Details`n`n"
        $result += "| SamAccountName | Display Name | Enabled | Match Types | Last Logon | Password Never Expires |`n"
        $result += "| --- | --- | --- | --- | --- | --- |`n"
        foreach ($user in ($potentialHoneyPots | Select-Object -First 25)) {
            $result += "| $($user.SamAccountName) | $($user.Name) | $($user.Enabled) | $($user.MatchTypes) | $($user.LastLogonDate) | $($user.PasswordNeverExpires) |`n"
        }

        if ($potentialHoneyPots.Count -gt 25) {
            $result += "| ... | ... | ... | ... | ... | ... ($($potentialHoneyPots.Count - 25) more) |`n"
        }
    } else {
        $result += "No potential honey pot users were identified using the configured naming rules.`n"
    }
    Write-Verbose "Counts computed"

    $testResultMarkdown = "Potential honey pot style Active Directory users were reviewed in detail.`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown
    Write-Verbose "Completed Test-MtAdUserHoneyPotDetails"

    return $testResult
}


