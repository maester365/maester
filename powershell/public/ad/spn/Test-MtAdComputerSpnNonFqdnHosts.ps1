function Test-MtAdComputerSpnNonFqdnHosts {
    <#
    .SYNOPSIS
    Counts computer SPNs with hosts that do not use fully qualified domain names (FQDN).

    .DESCRIPTION
    This test retrieves all Service Principal Names (SPNs) configured on computer objects
    and identifies those where the host portion is not a fully qualified domain name.
    Non-FQDN hosts in SPNs can cause authentication issues and may indicate misconfigurations.

    .EXAMPLE
    Test-MtAdComputerSpnNonFqdnHosts

    Returns $true if SPN data is accessible, $false otherwise.
    The test result includes the count of SPNs with non-FQDN hosts.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdComputerSpnNonFqdnHosts
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

    # Extract SPNs and check for FQDN
    $spnData = $computers | Where-Object { $null -ne $_.servicePrincipalName } | ForEach-Object {
        $computer = $_
        $computer.servicePrincipalName | ForEach-Object {
            # Parse SPN: serviceclass/host:port
            if ($_ -match "^([^/]+)/([^:]+)(?::(\d+))?$") {
                $serviceClass = $matches[1]
                $hostPart = $matches[2]
                $port = $matches[3]

                # Check if host is FQDN (contains a dot)
                $isFqdn = $hostPart -like "*.*"

                [PSCustomObject]@{
                    SPN = $_
                    ServiceClass = $serviceClass
                    Host = $hostPart
                    Port = $port
                    IsFqdn = $isFqdn
                    Computer = $computer.Name
                }
            }
        }
    }

    $totalSpns = ($spnData | Measure-Object).Count
    $nonFqdnSpns = $spnData | Where-Object { -not $_.IsFqdn }
    $nonFqdnCount = ($nonFqdnSpns | Measure-Object).Count
    $fqdnCount = $totalSpns - $nonFqdnCount

    # Test passes if we successfully retrieved SPN data
    $testResult = $true

    # Generate markdown results
    if ($testResult) {
        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Total SPNs | $totalSpns |`n"
        $result += "| FQDN Hosts | $fqdnCount |`n"
        $result += "| Non-FQDN Hosts | $nonFqdnCount |`n"

        if ($totalSpns -gt 0) {
            $percentage = [Math]::Round(($nonFqdnCount / $totalSpns) * 100, 2)
            $result += "| Non-FQDN Percentage | $percentage% |`n"
        }

        if ($nonFqdnCount -gt 0) {
            $result += "`n### Non-FQDN SPN Examples`n`n"
            $result += "| SPN | Computer |`n"
            $result += "| --- | --- |`n"

            # Show first 10 examples
            $examples = $nonFqdnSpns | Select-Object -First 10
            foreach ($example in $examples) {
                $result += "| $($example.SPN) | $($example.Computer) |`n"
            }

            if ($nonFqdnCount -gt 10) {
                $result += "| ... and $($nonFqdnCount - 10) more | |`n"
            }
        }

        $testResultMarkdown = "Active Directory computer SPN host analysis found $nonFqdnCount SPNs with non-FQDN hosts out of $totalSpns total.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory computer SPN data. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}






