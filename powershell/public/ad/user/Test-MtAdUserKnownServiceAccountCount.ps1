function Test-MtAdUserKnownServiceAccountCount {
    <#
    .SYNOPSIS
    Counts users that match known service account naming patterns.

    .DESCRIPTION
    This test identifies user objects whose SamAccountName or Name matches common
    service account naming conventions such as svc_, service_, _svc, sa_, or similar
    patterns. Consistent naming helps operations, but it also makes it easier to locate
    accounts that should receive stronger password, delegation, and monitoring controls.

    .EXAMPLE
    Test-MtAdUserKnownServiceAccountCount

    Returns $true if user data is accessible, $false otherwise.
    The test result includes the count of users matching known service account patterns.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdUserKnownServiceAccountCount
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Starting Test-MtAdUserKnownServiceAccountCount"
    $adState = Get-MtADDomainState
    Write-Verbose "Retrieved AD state"
    if ($null -eq $adState) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "Not connected to Active Directory."
        return $null
    }
    Write-Verbose "Filtering/counting user known service account count"

    $users = $adState.Users
    $serviceAccountPattern = '(?i)(^svc[_-]|^service[_-]|[_-]svc$|[_-]service$|^sa[_-]|[_-]sa$|^sqlsvc[_-]?|^appsvc[_-]?)'
    $knownServiceAccounts = $users | Where-Object {
        $identifiers = @($_.SamAccountName, $_.Name) | Where-Object {
            -not [string]::IsNullOrWhiteSpace($_)
        }

        ($identifiers | Where-Object {
            $_ -match $serviceAccountPattern
        } | Measure-Object).Count -gt 0
    }

    $serviceAccountCount = ($knownServiceAccounts | Measure-Object).Count
    $totalCount = ($users | Measure-Object).Count
    $testResult = $totalCount -gt 0

    if ($testResult) {
        $percentage = if ($totalCount -gt 0) {
            [Math]::Round(($serviceAccountCount / $totalCount) * 100, 2)
        } else {
            0
        }

        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Total Users | $totalCount |`n"
        $result += "| Users Matching Known Service Account Patterns | $serviceAccountCount |`n"
        $result += "| Service Account Pattern Percentage | $percentage% |`n`n"
    Write-Verbose "Counts computed"

        $testResultMarkdown = "Active Directory users have been analyzed. $serviceAccountCount out of $totalCount users ($percentage%) match common service account naming patterns.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory users. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown
    Write-Verbose "Completed Test-MtAdUserKnownServiceAccountCount"

    return $testResult
}


