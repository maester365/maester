<#
 .Synopsis
  Checks if the default app management policy is enabled.

 .Description
  GET /policies/defaultAppManagementPolicy

 .Example
  Test-MtAppManagementPolicyEnabled

.LINK
    https://maester.dev/docs/commands/Test-MtAppManagementPolicyEnabled
#>
function Test-MtAppManagementPolicyEnabled {
  [CmdletBinding()]
  [OutputType([bool])]
  param()

  try {
    $defaultAppManagementPolicy = Invoke-MtGraphRequest -RelativeUri 'policies/defaultAppManagementPolicy'
    Write-Verbose -Message "Default App Management Policy: $($defaultAppManagementPolicy.isEnabled)"
    $result = $defaultAppManagementPolicy.isEnabled -eq 'True'

    if ($result) {
      $resultMarkdown = 'Well done. Your tenant has an app management policy enabled.'
    } else {
      $resultMarkdown = 'Your tenant does not have an app management policy defined.'
    }

    Add-MtTestResultDetail -Result $resultMarkdown
    return $result
  } catch {
    Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
    return $null
  }
}
