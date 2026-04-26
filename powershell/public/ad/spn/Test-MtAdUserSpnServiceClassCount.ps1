function Test-MtAdUserSpnServiceClassCount {
    <#
    .SYNOPSIS
    Counts the distinct SPN service classes in use by user accounts.

    .DESCRIPTION
    This test retrieves all Service Principal Names (SPNs) configured on user objects
    and counts the distinct service classes in use. This helps identify what types of
    services are running under user accounts, which is important for security assessment.

    .EXAMPLE
    Test-MtAdUserSpnServiceClassCount

    Returns $true if SPN data is accessible, $false otherwise.
    The test result includes the count of distinct service classes on user accounts.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdUserSpnServiceClassCount
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    # Get AD domain state data (uses cached data if available)
    $adState = Get-MtADDomainState

    # If unable to retrieve AD data, skip the test
    if ($null -eq $adState) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory
        return $null
    }

    $users = $adState.Users

    # Extract all SPNs from user objects
    $allSpns = $users | Where-Object { $null -ne $_.servicePrincipalName } | ForEach-Object { $_.servicePrincipalName } | ForEach-Object { $_ }

    # Parse SPNs to extract service classes
    $serviceClasses = $allSpns | ForEach-Object {
        if ($_ -match "^([^/]+)") {
            $matches[1]
        }
    } | Select-Object -Unique | Sort-Object

    $serviceClassCount = ($serviceClasses | Measure-Object).Count
    $totalSpnCount = ($allSpns | Measure-Object).Count
    $usersWithSpns = ($users | Where-Object { $null -ne $_.servicePrincipalName } | Measure-Object).Count

    # Test passes if we successfully retrieved SPN data
    $testResult = $true

    # Generate markdown results
    if ($testResult) {
        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Total User SPNs | $totalSpnCount |`n"
        $result += "| Distinct Service Classes | $serviceClassCount |`n"
        $result += "| Users with SPNs | $usersWithSpns |`n"

        if ($serviceClassCount -gt 0) {
            $result += "| Service Classes | $($serviceClasses -join ', ') |`n"
        }

        $testResultMarkdown = "Active Directory user SPN service class analysis found $serviceClassCount distinct service classes across $totalSpnCount SPNs.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory user SPN data. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}




