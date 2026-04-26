function Test-MtAdDcSmbv311EnabledCount {
    <#
    .SYNOPSIS
    Counts domain controllers with SMBv3.1.1 protocol enabled.

    .DESCRIPTION
    This test checks how many domain controllers have SMBv3.1.1 enabled.
    SMBv3.1.1 is the latest version of the SMB protocol and includes
    security enhancements like pre-authentication integrity.

    .EXAMPLE
    Test-MtAdDcSmbv311EnabledCount

    Returns $true if SMB configuration data is accessible.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdDcSmbv311EnabledCount
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

    $smbConfigs = $adState.SmbConfigurations
    
    # Check if SMB configuration data was collected
    if ($smbConfigs.Count -eq 0) {
        $testResultMarkdown = "Unable to retrieve SMB configuration from domain controllers. This may require administrative privileges on the DCs."
        Add-MtTestResultDetail -Result $testResultMarkdown
        return $null
    }

    # Count DCs with SMBv3.1.1 enabled
    $smbv311EnabledDCs = $smbConfigs | Where-Object { $_.EnableSMB3_1_1Protocol -eq $true }
    $smbv311EnabledCount = ($smbv311EnabledDCs | Measure-Object).Count
    $smbv311DisabledCount = $smbConfigs.Count - $smbv311EnabledCount

    # Test passes if we successfully retrieved data
    $testResult = $smbConfigs.Count -gt 0

    # Generate markdown results
    $result = "| Metric | Value |`n"
    $result += "| --- | --- |`n"
    $result += "| Total DCs Checked | $($smbConfigs.Count) |`n"
    $result += "| DCs with SMBv3.1.1 Enabled | $smbv311EnabledCount |`n"
    $result += "| DCs with SMBv3.1.1 Disabled | $smbv311DisabledCount |`n"

    if ($smbv311EnabledCount -gt 0) {
        $result += "| DCs with SMBv3.1.1 Enabled | $($smbv311EnabledDCs.DCName -join ', ') |`n"
    }

    $testResultMarkdown = "SMBv3.1.1 protocol status has been analyzed on $($smbConfigs.Count) domain controller(s). $smbv311EnabledCount DC(s) have SMBv3.1.1 enabled.`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}

