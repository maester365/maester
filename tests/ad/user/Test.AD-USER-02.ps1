function Test-MtAdUserDormantEnabledCount {
    <#
    .SYNOPSIS
    Counts enabled user accounts that have been dormant beyond the configured threshold.

    .DESCRIPTION
    This test identifies enabled user accounts whose last recorded logon date is older
    than the configured threshold. Dormant enabled accounts increase risk because they may be forgotten,
    retain privileges, and become attractive targets for unauthorized access.

    .EXAMPLE
    Test-MtAdUserDormantEnabledCount

    .LINK
    https://maester.dev/docs/commands/Test-MtAdUserDormantEnabledCount
    #>
    [MaesterTest(
        Id = 'AD-USER-02',
        Title = 'Dormant enabled user count should be retrievable',
        Product = 'ad',
        Feature = 'users',
        Area = 'identity-lifecycle',
        ResourceType = 'User',
        Severity = 'Info',
        Mitre = 'T1078.002',
        Control = 'nist-800-53-r5:AC-2(3)',
        Service = 'ActiveDirectory',
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # Number of days without a logon before an enabled account is considered dormant.
        [ValidateRange(1, 3650)]
        [int] $DormantThresholdDays = 90
    )

    Write-Verbose "Starting Test-MtAdUserDormantEnabledCount"
    $adState = Get-MtADDomainState -Categories @('Users')
    Write-Verbose "Retrieved AD state"
    if ($null -eq $adState) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "Not connected to Active Directory."
        return $null
    }
    Write-Verbose "Filtering/counting user dormant enabled count"

    $thresholdDays = $DormantThresholdDays
    $thresholdDate = (Get-Date).AddDays(-$thresholdDays)
    $users = @($adState.Users)
    $enabledUsers = @($users | Where-Object { $_.Enabled -eq $true })
    $dormantUsers = @($enabledUsers | Where-Object {
            $null -ne $_.LastLogonDate -and $_.LastLogonDate -lt $thresholdDate
        })

    $dormantCount = $dormantUsers.Count
    $enabledCount = $enabledUsers.Count
    $totalCount = $users.Count

    $testResult = $null -ne $adState.Users

    if ($testResult) {
        $percentage = if ($enabledCount -gt 0) {
            [Math]::Round(($dormantCount / $enabledCount) * 100, 2)
        } else {
            0
        }

        $result = "| Metric | Value |" + "`n"
        $result += "| --- | --- |" + "`n"
        $result += "| Total Users | $totalCount |" + "`n"
        $result += "| Enabled Users | $enabledCount |" + "`n"
        $result += "| Dormant Enabled Users (>$thresholdDays days) | $dormantCount |" + "`n"
        $result += "| Dormant Percentage (of enabled) | $percentage% |" + "`n" + "`n"
    Write-Verbose "Counts computed"

        $testResultMarkdown = "Active Directory user objects have been analyzed. $dormantCount out of $enabledCount enabled users ($percentage%) have not logged on in more than $thresholdDays days.`n`n%TestResult%"
        if ($dormantCount -eq 0) {
            $oldestLastLogonDate = $enabledUsers |
                Where-Object { $null -ne $_.LastLogonDate } |
                Sort-Object -Property LastLogonDate |
                Select-Object -First 1 -ExpandProperty LastLogonDate

            if ($null -eq $oldestLastLogonDate) {
                $oldestLastLogon = 'unavailable'
                $daysUntilThreshold = 'unavailable'
            } else {
                $oldestLastLogonDate = [datetime]$oldestLastLogonDate
                $oldestLastLogon = $oldestLastLogonDate.ToString('yyyy-MM-dd')
                $daysUntilThreshold = [Math]::Max(1, [Math]::Ceiling(($oldestLastLogonDate.AddDays($thresholdDays) - (Get-Date)).TotalDays))
            }

            $testResultMarkdown += "`n`nThere are $enabledCount enabled users. The oldest last logon date is $oldestLastLogon. No users currently exceed the dormant threshold of $thresholdDays days. The oldest user would reach the threshold in $daysUntilThreshold days."
        }
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory user objects. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown
    Write-Verbose "Completed Test-MtAdUserDormantEnabledCount"

    return $testResult
}
