function Test-MtAppManagementPolicyEnabled {
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
  [MaesterTest(
      Id = 'MT.1002',
      Title = 'App management restrictions on applications and service principals is configured and enabled.',
      Severity = 'High',
      Category = 'Maester/Entra',
      Tag = ('App', 'Maester'),
      Service = 'Graph',
      Author = 'f-bader',
      Contributor = ('merill', 'BakkerJan')
  )]
  [CmdletBinding()]
  [OutputType([bool])]
  param()

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
}
