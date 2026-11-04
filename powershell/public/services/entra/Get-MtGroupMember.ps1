function Get-MtGroupMember {
    <#
    .Synopsis
    Returns all the members of the specific group ID.

    .Description
    Returns all the members of the specific group ID.

    A group that is not found (404), such as a deleted group or an external partner group assigned through GDAP,
    returns $null. Any other error, such as missing permissions or throttling, is thrown, so a check that depends on
    the members cannot pass without reading them.

    .Example
    Get-MtGroupMember

    .LINK
    https://maester.dev/docs/commands/Get-MtGroupMember
    #>
  [CmdletBinding()]
  param(
    # ID for the Entra group to return members for.
    [Parameter(Position = 0, mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [guid]$GroupId,
    # Include indirect members through nested groups.
    [switch]$Recursive
  )

  # Validate GroupId is not empty GUID
  if ($GroupId -eq [guid]::Empty) {
    Write-Error "GroupId cannot be an empty GUID."
    return $null
  }

  Write-Verbose -Message "Getting group members for group: $GroupId"

  try {
    $members = Invoke-MtGraphRequest -RelativeUri "groups/$GroupId/members" -ApiVersion v1.0
  } catch {
    if (Test-MtGraphNotFoundError -ErrorRecord $_) {
      Write-Verbose "Group ($GroupId) was not found in the tenant and will be skipped. This may be an external partner group assigned via GDAP, or the group may have been deleted. Details: $($_.Exception.Message)"
      return $null
    }
    # Keep the Graph exception as the inner exception, so callers can still read its status code. throw, not
    # $PSCmdlet.ThrowTerminatingError, so the calling check stops instead of continuing without the members.
    $exception = [System.InvalidOperationException]::new("Could not read the members of group ($GroupId) from Microsoft Graph: $($_.Exception.Message)", $_.Exception)
    throw [System.Management.Automation.ErrorRecord]::new($exception, 'MtGroupMemberReadFailed', $_.CategoryInfo.Category, $GroupId)
  }

  if (-not $Recursive) {
    return $members
  }

  # Process nested groups recursively. A nested group that cannot be read throws, like the outer group.
  $nestedGroups = $members | Where-Object { $_.'@odata.type' -eq "#microsoft.graph.group" }
  foreach ($nestedGroup in $nestedGroups) {
    if ($nestedGroup.id) {
      $nestedMembers = Get-MtGroupMember -GroupId $nestedGroup.id -Recursive
      if ($nestedMembers) {
        $members += $nestedMembers
      }
    }
  }

  return $members
}
