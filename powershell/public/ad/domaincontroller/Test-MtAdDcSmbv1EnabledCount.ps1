function Test-MtAdDcSmbv1EnabledCount {
    <#
    .SYNOPSIS
    Counts domain controllers with SMBv1 protocol enabled.

    .DESCRIPTION
    This test checks if SMBv1 protocol is enabled on any domain controllers.
    SMBv1 is an outdated protocol with known security vulnerabilities and should be
    disabled on all domain controllers to prevent attacks like EternalBlue.

    .EXAMPLE
    Test-MtAdDcSmbv1EnabledCount

    Returns $true if no DCs have SMBv1 enabled, $false if any DC has SMBv1 enabled.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdDcSmbv1EnabledCount
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

    # Count DCs with SMBv1 enabled
    $smbv1EnabledDCs = $smbConfigs | Where-Object { $_.EnableSMB1Protocol -eq $true }
    $smbv1EnabledCount = ($smbv1EnabledDCs | Measure-Object).Count
    $smbv1DisabledCount = $smbConfigs.Count - $smbv1EnabledCount

    # Test passes if no DCs have SMBv1 enabled
    $testResult = $smbv1EnabledCount -eq 0

    # Generate markdown results
    $result = "| Metric | Value |`n"
    $result += "| --- | --- |`n"
    $result += "| Total DCs Checked | $($smbConfigs.Count) |`n"
    $result += "| DCs with SMBv1 Enabled | $smbv1EnabledCount |`n"
    $result += "| DCs with SMBv1 Disabled | $smbv1DisabledCount |`n"

    if ($smbv1EnabledCount -gt 0) {
        $result += "| DCs with SMBv1 Enabled | $($smbv1EnabledDCs.DCName -join ', ') |`n"
        $testResultMarkdown = "❌ **Security Risk**: SMBv1 is enabled on $smbv1EnabledCount domain controller(s). SMBv1 should be disabled on all DCs due to known vulnerabilities.`n`n%TestResult%"
    } else {
        $testResultMarkdown = "✅ **Secure Configuration**: SMBv1 is disabled on all $($smbConfigs.Count) domain controller(s) that were checked.`n`n%TestResult%"
    }

    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}


