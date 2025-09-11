<#
.SYNOPSIS
    Returns a cached list of all role definitions in the tenant.

.DESCRIPTION
    This internal function provides a cached list of role definitions from Microsoft Graph.
    The results are cached in the session to avoid repeated API calls.
    Returns both display names and IDs for role validation and lookup.

.EXAMPLE
    $roles = Get-MtRoleList
    $validRoles = $roles.Keys

.NOTES
    This is an internal helper function used by Get-MtRoleMember and Get-MtRoleInfo
    to provide dynamic role validation without hardcoded lists.
#>
function Get-MtRoleList {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    $cacheKey = 'DirectoryRoleDefinitions'
    
    # Check if roles are already cached
    if ($__MtSession.GraphCache.ContainsKey($cacheKey)) {
        Write-Verbose "Using cached directory role definitions"
        return $__MtSession.GraphCache[$cacheKey]
    }

    Write-Verbose "Fetching directory role definitions from Microsoft Graph"
    
    try {
        # Use the same API endpoint as Get-MtRole
        $roleDefinitions = Invoke-MtGraphRequest -RelativeUri 'roleManagement/directory/roleDefinitions' -ApiVersion v1.0
        
        # Create a hashtable mapping display names (without spaces) to role IDs
        $roleMap = @{}
        foreach ($role in $roleDefinitions) {
            $roleName = $role.displayName -replace '\s+', ''  # Remove spaces for consistency
            $roleMap[$roleName] = $role.id
        }
        
        # Cache the result for the session
        $__MtSession.GraphCache[$cacheKey] = $roleMap
        
        Write-Verbose "Cached $($roleMap.Count) role definitions"
        return $roleMap
        
    } catch {
        Write-Warning "Failed to retrieve role definitions from Microsoft Graph: $($_.Exception.Message)"
        Write-Warning "Falling back to built-in role list. Some roles may not be available."
        
        # Return empty hashtable if API call fails - calling functions should handle fallback
        return @{}
    }
}