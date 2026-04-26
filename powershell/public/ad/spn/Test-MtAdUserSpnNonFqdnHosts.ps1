function Test-MtAdUserSpnNonFqdnHosts {
    <#
    .SYNOPSIS
    Counts user SPNs with hosts that do not use fully qualified domain names (FQDN).

    .DESCRIPTION
    This test retrieves all Service Principal Names (SPNs) configured on user objects
    and identifies those where the host portion is not a fully qualified domain name.
    Non-FQDN hosts in SPNs can cause authentication issues and may indicate misconfigurations.

    .EXAMPLE
    Test-MtAdUserSpnNonFqdnHosts

    Returns $true if SPN data is accessible, $false otherwise.
    The test result includes the count of user SPNs with non-FQDN hosts.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdUserSpnNonFqdnHosts
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Clarity in using plural')]
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

    # Extract SPNs and check for FQDN
    $spnData = $users | Where-Object { $null -ne $_.servicePrincipalName } | ForEach-Object {
        $user = $_
        $user.servicePrincipalName | ForEach-Object {
            # Parse SPN: serviceclass/host:port
            if ($_ -match "^([^/]+)/([^:]+)(?::(\d+))?$") {
                $serviceClass = $matches[1]
                $hostPart = $matches[2]
                $port = $matches[3]

                # Check if host is FQDN (contains a dot)
                $isFqdn = $hostPart -like "*.*"

                [PSCustomObject]@{
                    SPN          = $_
                    ServiceClass = $serviceClass
                    Host         = $hostPart
                    Port         = $port
                    IsFqdn       = $isFqdn
                    User         = $user.SamAccountName
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
        $result += "| Total User SPNs | $totalSpns |`n"
        $result += "| FQDN Hosts | $fqdnCount |`n"
        $result += "| Non-FQDN Hosts | $nonFqdnCount |`n"

        if ($totalSpns -gt 0) {
            $percentage = [Math]::Round(($nonFqdnCount / $totalSpns) * 100, 2)
            $result += "| Non-FQDN Percentage | $percentage% |`n"
        }

        if ($nonFqdnCount -gt 0) {
            $result += "`n### Non-FQDN SPN Examples`n`n"
            $result += "| SPN | User |`n"
            $result += "| --- | --- |`n"

            # Show first 10 examples
            $examples = $nonFqdnSpns | Select-Object -First 10
            foreach ($example in $examples) {
                $result += "| $($example.SPN) | $($example.User) |`n"
            }

            if ($nonFqdnCount -gt 10) {
                $result += "| ... and $($nonFqdnCount - 10) more | |`n"
            }
        }

        $testResultMarkdown = "Active Directory user SPN host analysis found $nonFqdnCount SPNs with non-FQDN hosts out of $totalSpns total.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory user SPN data. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}






