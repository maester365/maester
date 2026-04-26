function Test-MtAdUserSpnServiceClassUsage {
    <#
    .SYNOPSIS
    Provides a breakdown of SPN service class usage across user accounts.

    .DESCRIPTION
    This test retrieves all Service Principal Names (SPNs) configured on user objects
    and provides a detailed breakdown of how many users have each service class.
    This helps identify the service footprint and potential security risks on user accounts.

    .EXAMPLE
    Test-MtAdUserSpnServiceClassUsage

    Returns $true if SPN data is accessible, $false otherwise.
    The test result includes a breakdown of service classes with counts.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdUserSpnServiceClassUsage
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

    # Extract all SPNs from user objects with their service classes
    $spnData = $users | Where-Object { $null -ne $_.servicePrincipalName } | ForEach-Object {
        $user = $_
        $user.servicePrincipalName | ForEach-Object {
            if ($_ -match "^([^/]+)") {
                [PSCustomObject]@{
                    ServiceClass = $matches[1]
                    User = $user.SamAccountName
                    SPN = $_
                }
            }
        }
    }

    # Group by service class
    $serviceClassGroups = $spnData | Group-Object ServiceClass | Sort-Object Count -Descending

    $serviceClassCount = ($serviceClassGroups | Measure-Object).Count
    $totalSpnCount = ($spnData | Measure-Object).Count
    $usersWithSpns = ($users | Where-Object { $null -ne $_.servicePrincipalName } | Measure-Object).Count

    # Test passes if we successfully retrieved SPN data
    $testResult = $true

    # Generate markdown results
    if ($testResult) {
        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Total User SPNs | $totalSpnCount |`n"
        $result += "| Distinct Service Classes | $serviceClassCount |`n"
        $result += "| Users with SPNs | $usersWithSpns |`n`n"

        if ($serviceClassCount -gt 0) {
            $result += "### Service Class Breakdown`n`n"
            $result += "| Service Class | Count | Percentage |`n"
            $result += "| --- | --- | --- |`n"

            foreach ($group in $serviceClassGroups) {
                $percentage = [Math]::Round(($group.Count / $totalSpnCount) * 100, 2)
                $result += "| $($group.Name) | $($group.Count) | $percentage% |`n"
            }
        }

        $testResultMarkdown = "Active Directory user SPN service class usage has been analyzed.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory user SPN data. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}


