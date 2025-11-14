<#
.SYNOPSIS
    Check the Intune Diagnostic Settings for Audit Logs.
.DESCRIPTION
    Enumarate all diagnostic settings for Intune and check if Audit Logs are being sent to a destination (Log Analytics, Storage Account, Event Hub).

.EXAMPLE
    Test-MtFeatureUpdatePolicy

    Returns true if any Intune diagnostic settings include Audit Logs and are being sent to a destination (Log Analytics, Storage Account, Event Hub).

.LINK
    https://maester.dev/docs/commands/Test-MtFeatureUpdatePolicy
#>
function Test-MtFeatureUpdatePolicy {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Testing Apple Volume Purchase Program Token for Intune...'
    if (-not (Get-MtLicenseInformation -Product Intune)) {
        Add-MtTestResultDetail -SkippedBecause NotLicensedIntune
        return $null
    }


    try {
        $featureUpdateProfiles = @(Invoke-MtGraphRequest -RelativeUri 'deviceManagement/windowsFeatureUpdateProfiles' -ApiVersion beta)
        $unsupportedBuilds = @($featureUpdateProfiles | Where-Object {
                [datetime]$_.endOfSupportDate -lt (Get-Date)
            })

        $testResultMarkdown = "No unsupported Windows Feature Update Profiles found."

        if ($unsupportedBuilds.Count -gt 0) {
            $testResultMarkdown = "Unsupported Windows Feature Update Profiles:`n"
            $testResultMarkdown += "| Name | Version | EndOfSupportDate |`n"
            $testResultMarkdown += "| --- | --- | --- |`n"
            foreach ($config in $unsupportedBuilds) {
                $testResultMarkdown += "| {0} | {1} | {2} |`n" -f $config.displayName, $config.featureUpdateVersion, $config.endOfSupportDate
            }
        }

        Add-MtTestResultDetail -Result $testResultMarkdown
        return ($unsupportedBuilds.Count -eq 0)
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
