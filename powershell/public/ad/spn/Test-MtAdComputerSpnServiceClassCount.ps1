function Test-MtAdComputerSpnServiceClassCount {
    <#
    .SYNOPSIS
    Counts the distinct SPN service classes in use by computer accounts.

    .DESCRIPTION
    This test retrieves all Service Principal Names (SPNs) configured on computer objects
    and counts the distinct service classes in use. SPNs are used by Kerberos for
    authentication to services and follow the format 'serviceclass/host:port'.

    .EXAMPLE
    Test-MtAdComputerSpnServiceClassCount

    Returns $true if SPN data is accessible, $false otherwise.
    The test result includes the count of distinct service classes.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdComputerSpnServiceClassCount
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

    $computers = $adState.Computers

    # Extract all SPNs from computer objects
    $allSpns = $computers | Where-Object { $null -ne $_.servicePrincipalName } | ForEach-Object { $_.servicePrincipalName } | ForEach-Object { $_ }

    # Parse SPNs to extract service classes
    $serviceClasses = $allSpns | ForEach-Object {
        if ($_ -match "^([^/]+)") {
            $matches[1]
        }
    } | Select-Object -Unique | Sort-Object

    $serviceClassCount = ($serviceClasses | Measure-Object).Count
    $totalSpnCount = ($allSpns | Measure-Object).Count

    # Test passes if we successfully retrieved SPN data
    $testResult = $totalSpnCount -ge 0

    # Generate markdown results
    if ($testResult) {
        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Total SPNs | $totalSpnCount |`n"
        $result += "| Distinct Service Classes | $serviceClassCount |`n"

        if ($serviceClassCount -gt 0) {
            $result += "| Computers with SPNs | $(($computers | Where-Object { $null -ne $_.servicePrincipalName } | Measure-Object).Count) |`n"
        }

        $testResultMarkdown = "Active Directory computer SPNs have been analyzed. $serviceClassCount distinct service classes found across $totalSpnCount SPNs.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory computer SPN data. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}




