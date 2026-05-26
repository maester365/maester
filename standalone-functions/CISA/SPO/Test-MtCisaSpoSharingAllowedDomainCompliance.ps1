function Test-MtCisaSpoSharingAllowedDomainCompliance {
    <#
    .SYNOPSIS
    Checks state of SharePoint Online sharing

    .DESCRIPTION
    External sharing SHALL be restricted to approved external domains and/or users in approved security groups per interagency collaboration needs.
    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtCisaSpoSharingAllowedDomainCompliance
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

    if($policy.sharingCapability -eq "disabled"){
        return $null
    }

    $resultPolicy = $policy.sharingAllowedDomainList

    $testResult = ($resultPolicy | Measure-Object).Count -gt 0
    $resultPolicy | ForEach-Object {
        $result = "* $_`n"
        $result | Out-Null
    }


    return $testResult

}
