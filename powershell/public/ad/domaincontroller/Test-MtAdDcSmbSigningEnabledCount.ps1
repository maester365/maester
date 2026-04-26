function Test-MtAdDcSmbSigningEnabledCount {
    <#
    .SYNOPSIS
    Counts domain controllers with SMB signing enabled.

    .DESCRIPTION
    This test checks how many domain controllers have SMB signing enabled.
    SMB signing helps prevent man-in-the-middle attacks by ensuring the
    integrity of SMB communications. It should be enabled on all DCs.

    .EXAMPLE
    Test-MtAdDcSmbSigningEnabledCount

    Returns $true if all DCs have SMB signing enabled, $false otherwise.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdDcSmbSigningEnabledCount
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

    # Count DCs with SMB signing enabled/required
    $signingEnabledDCs = $smbConfigs | Where-Object { $_.EnableSecuritySignature -eq $true }
    $signingRequiredDCs = $smbConfigs | Where-Object { $_.RequireSecuritySignature -eq $true }
    $signingEnabledCount = ($signingEnabledDCs | Measure-Object).Count
    $signingRequiredCount = ($signingRequiredDCs | Measure-Object).Count
    $notEnabledCount = $smbConfigs.Count - $signingEnabledCount

    # Test passes if all DCs have SMB signing enabled
    $testResult = $signingEnabledCount -eq $smbConfigs.Count

    # Generate markdown results
    $result = "| Metric | Value |`n"
    $result += "| --- | --- |`n"
    $result += "| Total DCs Checked | $($smbConfigs.Count) |`n"
    $result += "| DCs with Signing Enabled | $signingEnabledCount |`n"
    $result += "| DCs with Signing Required | $signingRequiredCount |`n"
    $result += "| DCs without Signing | $notEnabledCount |`n"

    if ($signingEnabledCount -eq $smbConfigs.Count) {
        $testResultMarkdown = "✅ **Secure Configuration**: SMB signing is enabled on all $($smbConfigs.Count) domain controller(s).`n`n%TestResult%"
    } else {
        $notEnabledDCs = $smbConfigs | Where-Object { $_.EnableSecuritySignature -eq $false }
        $result += "| DCs without Signing | $($notEnabledDCs.DCName -join ', ') |`n"
        $testResultMarkdown = "⚠️ **Security Warning**: SMB signing is not enabled on $notEnabledCount domain controller(s). SMB signing should be enabled on all DCs to prevent man-in-the-middle attacks.`n`n%TestResult%"
    }

    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}




