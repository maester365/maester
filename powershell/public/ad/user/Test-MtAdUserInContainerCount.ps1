function Test-MtAdUserInContainerCount {
    <#
    .SYNOPSIS
    Counts users located in container objects instead of OUs.

    .DESCRIPTION
    This test identifies user objects whose distinguished name indicates they are
    stored beneath a container path (CN=) rather than an organizational unit (OU=).
    Users in default or custom containers can be harder to manage consistently because
    containers do not support the same delegation and Group Policy design patterns as OUs.

    .EXAMPLE
    Test-MtAdUserInContainerCount

    Returns $true if user data is accessible, $false otherwise.
    The test result includes the count of users located in container objects.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdUserInContainerCount
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
    $usersInContainers = $users | Where-Object {
        $_.DistinguishedName -and (
            $_.DistinguishedName -like "CN=*,CN=Users,*" -or
            $_.DistinguishedName -match '^CN=[^,]+,CN='
        )
    }

    $defaultUsersContainerCount = ($usersInContainers | Where-Object {
        $_.DistinguishedName -like "CN=*,CN=Users,*"
    } | Measure-Object).Count
    $containerCount = ($usersInContainers | Measure-Object).Count
    $totalCount = ($users | Measure-Object).Count
    $testResult = $totalCount -gt 0

    if ($testResult) {
        $percentage = if ($totalCount -gt 0) {
            [Math]::Round(($containerCount / $totalCount) * 100, 2)
        } else {
            0
        }

        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Total Users | $totalCount |`n"
        $result += "| Users in CN=Users | $defaultUsersContainerCount |`n"
        $result += "| Users in Container Paths | $containerCount |`n"
        $result += "| Container Percentage | $percentage% |`n`n"

        $testResultMarkdown = "Active Directory users have been analyzed. $containerCount out of $totalCount users ($percentage%) are located in container paths such as CN=Users instead of OUs.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory users. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
