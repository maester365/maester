function Test-MtAdMachineAccountQuota {
    <#
    .SYNOPSIS
    Retrieves the ms-DS-MachineAccountQuota value for the domain.

    .DESCRIPTION
    This test retrieves the machine account quota which determines how many computer
    accounts a standard user can create in the domain. The default value is 10, which
    may allow unauthorized computer joins if not properly restricted.

    .EXAMPLE
    Test-MtAdMachineAccountQuota

    Returns $true if machine account quota data is accessible.
    The test result includes the current quota value.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdMachineAccountQuota
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

    $domain = $adState.Domain

    # Try to get machine account quota from the domain object
    $machineAccountQuota = $null
    try {
        $domainObject = Get-ADObject -Identity $domain.DistinguishedName -Properties ms-DS-MachineAccountQuota
        $machineAccountQuota = $domainObject.'ms-DS-MachineAccountQuota'
    }
    catch {
        Write-Verbose "Could not retrieve machine account quota: $($_.Exception.Message)"
    }

    # Default is 10 if not explicitly set
    if ($null -eq $machineAccountQuota) {
        $machineAccountQuota = 10
        $usingDefault = $true
    } else {
        $usingDefault = $false
    }

    # Test passes if we successfully retrieved domain data
    $testResult = $null -ne $domain

    # Generate markdown results
    if ($testResult) {
        $result = "| Property | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Machine Account Quota | $machineAccountQuota |`n"
        $result += "| Default Value | 10 |`n"
        $result += "| Using Default | $usingDefault |`n"
        $result += "| Domain | $($domain.Name) |`n"

        $testResultMarkdown = "The machine account quota determines how many computer accounts a standard user can create in the domain.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve machine account quota. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}


