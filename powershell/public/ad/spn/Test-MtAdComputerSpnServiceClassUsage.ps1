function Test-MtAdComputerSpnServiceClassUsage {
    <#
    .SYNOPSIS
    Provides a breakdown of SPN service class usage across computer accounts.

    .DESCRIPTION
    This test retrieves all Service Principal Names (SPNs) configured on computer objects
    and provides a detailed breakdown of how many computers use each service class.
    This helps identify the service footprint and potential security risks.

    .EXAMPLE
    Test-MtAdComputerSpnServiceClassUsage

    Returns $true if SPN data is accessible, $false otherwise.
    The test result includes a breakdown of service classes with counts.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdComputerSpnServiceClassUsage
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

    # Extract all SPNs from computer objects with their service classes
    $spnData = $computers | Where-Object { $null -ne $_.servicePrincipalName } | ForEach-Object {
        $computer = $_
        $computer.servicePrincipalName | ForEach-Object {
            if ($_ -match "^([^/]+)") {
                [PSCustomObject]@{
                    ServiceClass = $matches[1]
                    Computer = $computer.Name
                    SPN = $_
                }
            }
        }
    }

    # Group by service class
    $serviceClassGroups = $spnData | Group-Object ServiceClass | Sort-Object Count -Descending

    $serviceClassCount = ($serviceClassGroups | Measure-Object).Count
    $totalSpnCount = ($spnData | Measure-Object).Count

    # Test passes if we successfully retrieved SPN data
    $testResult = $totalSpnCount -ge 0

    # Generate markdown results
    if ($testResult) {
        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Total SPNs | $totalSpnCount |`n"
        $result += "| Distinct Service Classes | $serviceClassCount |`n`n"

        if ($serviceClassCount -gt 0) {
            $result += "### Service Class Breakdown`n`n"
            $result += "| Service Class | Count | Percentage |`n"
            $result += "| --- | --- | --- |`n"

            foreach ($group in $serviceClassGroups) {
                $percentage = [Math]::Round(($group.Count / $totalSpnCount) * 100, 2)
                $result += "| $($group.Name) | $($group.Count) | $percentage% |`n"
            }
        }

        $testResultMarkdown = "Active Directory computer SPN service class usage has been analyzed.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory computer SPN data. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}


