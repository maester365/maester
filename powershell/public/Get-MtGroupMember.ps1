function Get-MtGroupMember {
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

  try {
    $group = Invoke-MtGraphRequest -RelativeUri "groups/$GroupId/" -ApiVersion v1.0
    if (-not $group) {
      Write-Verbose "Group ($GroupId) was not found in the tenant and will be skipped. This may be an external partner group assigned via GDAP, or the group may have been deleted."
      return $null
    }
  } catch {
    # Check status code via Response.StatusCode (Invoke-MgGraphRequest pattern used in this repo),
    # then via the typed StatusCode property (.NET 5+/PS7), then fall back to message matching.
    $is404 = ($_.Exception.Response.StatusCode -eq 404) -or
             ($_.Exception.StatusCode -eq [System.Net.HttpStatusCode]::NotFound) -or
             ($_.Exception.Message -match 'NotFound|404')
    if ($is404) {
      Write-Verbose "Group ($GroupId) was not found in the tenant and will be skipped. This may be an external partner group assigned via GDAP, or the group may have been deleted. Details: $($_.Exception.Message)"
    } else {
      Write-Warning "Error obtaining group ($GroupId) from Microsoft Graph. Confirm the group exists in your tenant. Details: $($_.Exception.Message)"
    }
    return $null
  }

  Write-Verbose -Message "Getting group members for group: $($group.displayName) ($GroupId)"

  try {
    $members = Invoke-MtGraphRequest -RelativeUri "groups/$GroupId/members" -ApiVersion v1.0

    if (-not $Recursive) {
      return $members
    }

    # Process nested groups recursively
    $nestedGroups = $members | Where-Object { $_.'@odata.type' -eq "#microsoft.graph.group" }
    foreach ($nestedGroup in $nestedGroups) {
      if ($nestedGroup.id) {
        try {
          $nestedMembers = Get-MtGroupMember -GroupId $nestedGroup.id -Recursive
          if ($nestedMembers) {
            $members += $nestedMembers
          }
        } catch {
          Write-Warning "Failed to get members for nested group '$($nestedGroup.id)': $($_.Exception.Message)"
        }
      }
    }

    return $members

  } catch {
    Write-Error "Error retrieving group members for group '$GroupId': $($_.Exception.Message)"
    return $null
  }
}
