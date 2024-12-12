<#
 .Synopsis
  Returns all the members of the specific group ID.

 .Description
  Returns all the members of the specific group ID.

 .Example
  Get-MtGroupMember

.LINK
    https://maester.dev/docs/commands/Get-MtGroupMember
#>
function Get-MtGroupMember {
  [CmdletBinding()]
  param(
    [Parameter(Position = 0, mandatory = $true)]
    # ID for the Entra group to return members for.
    [guid]$GroupId,
    # Include indirect members through nested groups.
    [switch]$Recursive
  )

  try {
    Invoke-MtGraphRequest -RelativeUri "groups/$GroupId/" -ApiVersion v1.0 | Out-Null
  } catch {
    Write-Error "Error obtaining group ($GroupId) from Microsoft Graph. Confirm the group exists in your tenant."
    return $null
  }

  Write-Verbose -Message "Getting group members."

  $members = @()
  $members += Invoke-MtGraphRequest -RelativeUri "groups/$GroupId/members" -ApiVersion v1.0

  if (-not $recursive) {
    return $members
  }

  $members | Where-Object {`
      $_.'@odata.type' -eq "#microsoft.graph.group"
  } | ForEach-Object {`
      $members += Get-MtGroupMember -GroupId $_.id -Recursive
  }

  return $members

}