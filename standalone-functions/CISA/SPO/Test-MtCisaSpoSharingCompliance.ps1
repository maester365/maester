function Test-MtCisaSpoSharingCompliance {
    <#
    .SYNOPSIS
    Checks state of SharePoint Online sharing

    .DESCRIPTION
    External sharing for SharePoint SHALL be limited to Existing guests or Only People in your organization.
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtCisaSpoSharingCompliance
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
    $policy = Invoke-MgGraphRequest -Uri 'https://graph.microsoft.com/v1.0/admin/sharepoint/settings' -ApiVersion "v1.0"

    $resultPolicy = $policy | Where-Object {
        $_.sharingCapability -in @("disabled","existingExternalUserSharingOnly")
    }

    $testResult = ($resultPolicy | Measure-Object).Count -gt 0

    if ($testResult) {
    } else {
        $policy | ForEach-Object {
            $result = "* $($_.sharingCapability)`n"
            $result | Out-Null
        }
    }


    return $testResult

}
