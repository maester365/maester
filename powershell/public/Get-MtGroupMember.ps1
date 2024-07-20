<#
 .Synopsis
  Returns all the members of the specific group ID.

 .Description

 .Example
  Get-MtGroupMember

.LINK
    https://maester.dev/docs/commands/Get-MtGroupMember
#>
function Get-MtGroupMember {
  [CmdletBinding()]
  param(
    [Parameter(Position=0,mandatory=$true)]
    [guid]$groupId,
    [switch]$Recursive
  )

  Write-Verbose -Message "Getting group members."

  $members = @()
  $members += Invoke-MtGraphRequest -RelativeUri "groups/$groupId/members" -ApiVersion v1.0

  if(-not $recursive){
    return $members
  }

  $members | Where-Object {`
    $_.'@odata.type' -eq "#microsoft.graph.group"
  } | ForEach-Object {`
    $members += Get-MtGroupMember -groupId $_.id -Recursive
  }

  return $members

}