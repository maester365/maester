function Test-MtAppManagementPolicyEnabledCompliance {
    <#
    .SYNOPSIS


    .DESCRIPTION

    Pure standalone compliance check function.
    Returns true if compliant, false if non-compliant, null if skipped or error.

    .EXAMPLE
    $result = Test-MtAppManagementPolicyEnabledCompliance
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
    $defaultAppManagementPolicy = Invoke-MgGraphRequest -Uri 'https://graph.microsoft.com/v1.0/policies/defaultAppManagementPolicy'
    Write-Verbose -Message "Default App Management Policy: $($defaultAppManagementPolicy.isEnabled)"
    $result = $defaultAppManagementPolicy.isEnabled -eq 'True'

    if ($result) {
      $resultMarkdown = 'Well done. Your tenant has an app management policy enabled.'
    } else {
      $resultMarkdown = 'Your tenant does not have an app management policy defined.'
    }

    return $result
  } catch {
    return $null
  }

}
