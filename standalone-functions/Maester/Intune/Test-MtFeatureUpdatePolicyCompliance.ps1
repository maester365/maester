function Test-MtFeatureUpdatePolicyCompliance {
    <#
    .SYNOPSIS
    Check whether a Windows Feature Update Policy in Intune is using unsupported builds.

    .DESCRIPTION
    This command checks the Windows Feature Update Policies configured in Microsoft Intune to identify any policies that are using Windows builds that are no longer supported by Microsoft.
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtFeatureUpdatePolicyCompliance
    if ($result -eq $true) { Write-Host "Compliant" }
    elseif ($result -eq $false) { Write-Host "Non-Compliant" }
    else { Write-Host "Skipped or Error" }

    .OUTPUTS
    bool|null - Returns true if compliant, false if non-compliant, null if skipped or error
    #>
    [CmdletBinding()]
    [OutputType([bool], [nullable])]
    param()

    # Phase 1: Prerequisites Check
    # Phase 2: Data Collection & Phase 3: Compliance Validation
    Write-Verbose 'Testing Windows Feature Update Policies for unsupported builds...'

    try {
        Write-Verbose 'Retrieving Windows Feature Update Profiles status...'
        $featureUpdateProfiles = Invoke-MgGraphRequest -Uri 'https://graph.microsoft.com/beta/deviceManagement/windowsFeatureUpdateProfiles'

        if (($featureUpdateProfiles | Measure-Object).Count -eq 0) {
            throw [System.Management.Automation.ItemNotFoundException]::new('No Windows Feature Update Profiles found.')
        }

        $unsupportedBuilds = @($featureUpdateProfiles | Where-Object {
                [datetime]$_.endOfSupportDate -lt (Get-Date)
            })


        if ($unsupportedBuilds.Count -gt 0) {
        }

        return ($unsupportedBuilds.Count -eq 0)
    } catch [System.Management.Automation.ItemNotFoundException] {
    } catch {
        return $null
    }

}
