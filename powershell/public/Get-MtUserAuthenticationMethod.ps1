<#
.SYNOPSIS
  Get the authentication methods for the specified user

.DESCRIPTION
  Get the authentication method from the /users/{id}/authentication/methods endpoint and
  appends the `typeDisplayName` and `isMfa` properties to each authentication method.

  The user authentication method returned by Graph is missing key information such as the
  display name and whether an auth method is a multi-factor authentication method or not.

  This cmdlet also returns an IsMfa status for the overall user object and is set to true
  if the user has at least one MFA method enabled.

  Note: The overall IsMfa status may not be accurate in tenants that identity federation
  or authentication methods like Certificate Based Authentication that don't have a state
  registered against the user object.

.EXAMPLE
  Get-MtUserAuthenticationMethod -UserId 'john@contoso.com'

  # Get the authentication methods for the specified user

.LINK
    https://maester.dev/docs/commands/Get-MtUserAuthenticationMethod
#>
function Get-MtUserAuthenticationMethod {
  [CmdletBinding()]
  param(
    # The GUID or user principal name of the user to get Authentication Methods for.
    [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline)] $UserId
  )

  process {
    function AddAuthMethodInfo ($userAuthMethod) {
      $authMethodInfo = Get-MtUserAuthenticationMethodInfoByType -AuthenticationMethod $userAuthMethod

      $userAuthMethod | Add-Member -MemberType NoteProperty -Name "typeDisplayName" -Value $authMethodInfo.DisplayName -ErrorAction SilentlyContinue
      $userAuthMethod | Add-Member -MemberType NoteProperty -Name "isMfa" -Value $authMethodInfo.IsMfa -ErrorAction SilentlyContinue
    }

    Write-Verbose "Querying graph for user authentication methods for $UserId"
    $userAuthMethods = Invoke-MtGraphRequest -RelativeUri "users/$UserId/authentication/methods"

    Write-Verbose "Appending auth method displayName and isMfa properties to each auth method."
    $IsMfa = $false
    foreach ($method in $userAuthMethods) {
      AddAuthMethodInfo $method
      if ($method.IsMfa) {
        $IsMfa = $true
      }
    }

    $userInfo = [PSCustomObject][Ordered]@{
      UserId                = $userId
      IsMfa                 = $IsMfa
      AuthenticationMethods = @($userAuthMethods)
    }

    Write-Output $userInfo
  }
}
