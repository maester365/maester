function Test-MtAppleVolumePurchaseProgramTokenCompliance {
    <#
    .SYNOPSIS
    Check the validity of the Apple Volume Purchase Program (VPP) token for Intune.

    .DESCRIPTION
    The Apple Volume Purchase Program (VPP) token is required to synchronize Apple store apps with Microsoft Intune. This command checks if the VPP token is valid and not expired.
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtAppleVolumePurchaseProgramTokenCompliance
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
        Write-Verbose 'Retrieving Apple Volume Purchase Program token status...'
        $expirationThresholdDays = 30
        $vppTokens = Invoke-MgGraphRequest -Uri 'https://graph.microsoft.com/beta/deviceAppManagement/vppTokens'

        if (($vppTokens | Measure-Object).Count -eq 0) {
            throw [System.Management.Automation.ItemNotFoundException]::new('No Apple Volume Purchase Program tokens found.')
        }


        $healthStatus = foreach ($token in $vppTokens) {
            $expiresInDays = [System.Math]::Ceiling(([datetime]$token.expirationDateTime - (Get-Date)).TotalDays)
            $lastSyncDiffDays = [System.Math]::Floor(((Get-Date) - [datetime]$token.lastSyncDateTime).TotalDays)
            Write-Output $($expiresInDays -gt $expirationThresholdDays -and $lastSyncDiffDays -le 1)
        }


        return $healthStatus -notcontains $false
    } catch [System.Management.Automation.ItemNotFoundException] {
    } catch {
        return $null
    }

}
