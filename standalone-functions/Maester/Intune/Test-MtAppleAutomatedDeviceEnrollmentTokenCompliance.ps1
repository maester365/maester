function Test-MtAppleAutomatedDeviceEnrollmentTokenCompliance {
    <#
    .SYNOPSIS
    Check the validity of the Apple Automated Device Enrollment (ADE) token for Intune.

    .DESCRIPTION
    The Apple Automated Device Enrollment (ADE) token is required to synchronize Apple devices with Microsoft Intune. This command checks if the ADE token is valid and not expired.
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtAppleAutomatedDeviceEnrollmentTokenCompliance
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

    try {
        Write-Verbose 'Retrieving Apple Automated Device Enrollment token status...'
        $expirationThresholdDays = 30
        $adeTokens = Invoke-MgGraphRequest -Uri 'https://graph.microsoft.com/beta/deviceManagement/depOnboardingSettings'

        if (($adeTokens | Measure-Object).Count -eq 0) {
            throw [System.Management.Automation.ItemNotFoundException]::new('No Apple Automated Device Enrollment tokens found.')
        }

        Write-Verbose ('{0} Apple Automated Device Enrollment token(s) found.' -f $adeTokens.Count)

        $healthStatus = foreach ($token in $adeTokens) {
            $expiresInDays = [System.Math]::Ceiling(([datetime]$token.tokenExpirationDateTime - (Get-Date)).TotalDays)
            $lastSyncDiffDays = [System.Math]::Floor(((Get-Date) - [datetime]$token.lastSuccessfulSyncDateTime).TotalDays)
            Write-Output $($expiresInDays -gt $expirationThresholdDays -and $lastSyncDiffDays -eq 0)
        }


        return $healthStatus -notcontains $false
    } catch [System.Management.Automation.ItemNotFoundException] {
    } catch {
    }

}
