<#
.SYNOPSIS
  Get the MFA Methods for the supplied user

.DESCRIPTION
    This function builds an object with the status of each type of MFA for the supplier user.
    There is then an overall `status` that is "enabled" when a user has some form of MFA on their account.

.PARAMETER UserId
    The GUID of the user to get MFA Methods for.

.EXAMPLE
    Get-MtMFAMethods -UserId $userId
    # Get the mfa mthods for $userId

#>
Function Get-MtMFAMethods {
  param(
    [Parameter(Mandatory = $true)] $UserId
  )
  process{
    # Get MFA details for each user
    [array]$mfaData = Get-MgUserAuthenticationMethod -UserId $userId

    $returnData = [PSCustomObject][Ordered]@{
      userId = $userId
      enabled = $false
      methods = @()
    }

    ForEach ($method in $mfaData){
      if(-not ($method.AdditionalProperties["@odata.type"] -eq "#microsoft.graph.passwordAuthenticationMethod")){
        # This is not password authentication so some form of MFA is setup on the user.
        $returnData.enabled = $true
      }

      $returnData.methods += $method.AdditionalProperties["@odata.type"] -replace "#microsoft.graph.", "" -replace "AuthenticationMethod", ""
    }

    return $returnData
  }
}