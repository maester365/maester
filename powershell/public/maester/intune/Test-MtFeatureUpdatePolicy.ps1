<#
.SYNOPSIS
    Check whether a Windows Feature Update Policy in Intune is using unsupported builds.
.DESCRIPTION
    This command checks the Windows Feature Update Policies configured in Microsoft Intune to identify any policies that are using Windows builds that are no longer supported by Microsoft.

.EXAMPLE
    Test-MtFeatureUpdatePolicy

    Returns true if no Feature Update Policies are using unsupported builds, false if any policies are found using unsupported builds.

.LINK
    https://maester.dev/docs/commands/Test-MtFeatureUpdatePolicy
#>
function Test-MtFeatureUpdatePolicy {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Testing Windows Feature Update Policies for unsupported builds...'
    if (-not (Get-MtLicenseInformation -Product Intune)) {
        Add-MtTestResultDetail -SkippedBecause NotLicensedIntune
        return $null
    }

    try {
        Write-Verbose 'Retrieving Windows Feature Update Profiles status...'
        $featureUpdateProfiles = Invoke-MtGraphRequest -RelativeUri 'deviceManagement/windowsFeatureUpdateProfiles' -ApiVersion beta

        if (($featureUpdateProfiles | Measure-Object).Count -eq 0) {
            throw [System.Management.Automation.ItemNotFoundException]::new('No Windows Feature Update Profiles found.')
        }

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
    } catch [System.Management.Automation.ItemNotFoundException] {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason $_
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
