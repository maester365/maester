function Get-MtAuthorization {
    <#
    .SYNOPSIS
    Gathers the available permissions and roles for the current connected services.

    .DESCRIPTION
    This function is called at the start of a Maester run to determine what the current
    session is authorized to do. The results are stored in $__MtSession.Authorization
    and used by tests to gracefully skip if required permissions are missing.
    #>
    [CmdletBinding()]
    param()

    if ($null -ne $__MtSession.Authorization) {
        return $__MtSession.Authorization
    }

    $auth = @{
        Graph = @()
        ExchangeOnline = @()
        Azure = @()
        Teams = @()
        EntraRoles = @()
    }

    # 1. Graph Scopes
    if ($mgContext = Get-MgContext) {
        $auth.Graph = $mgContext.Scopes
        Write-Verbose "Gathered $($auth.Graph.Count) Graph scopes."

        # 2. Entra Roles
        try {
            if ($mgContext.AuthType -eq 'Delegated') {
                $memberships = Invoke-MtGraphRequest -RelativeUri 'me/memberOf' -ErrorAction SilentlyContinue
                $auth.EntraRoles = $memberships | Where-Object { $_.'@odata.type' -eq '#microsoft.graph.directoryRole' } | Select-Object -ExpandProperty displayName
            } else {
                # Application permissions - check the service principal for the current app
                # We need the service principal ID (not AppId).
                $sp = Invoke-MtGraphRequest -RelativeUri "servicePrincipals" -Filter "appId eq '$($mgContext.ClientId)'" -ErrorAction SilentlyContinue
                # Handle collection return
                $spId = if ($sp -is [array]) { $sp[0].id } else { $sp.id }
                
                if ($spId) {
                    $memberships = Invoke-MtGraphRequest -RelativeUri "servicePrincipals/$spId/memberOf" -ErrorAction SilentlyContinue
                    $auth.EntraRoles = $memberships | Where-Object { $_.'@odata.type' -eq '#microsoft.graph.directoryRole' } | Select-Object -ExpandProperty displayName
                }
            }
            Write-Verbose "Gathered $($auth.EntraRoles.Count) Entra roles."
        } catch {
            Write-Verbose "Failed to gather Entra roles: $($_.Exception.Message)"
        }
    }

    # 3. Exchange Online Roles
    if (Test-MtConnection -Service ExchangeOnline) {
        try {
            $roleAssignments = Get-MtExo -Request ManagementRoleAssignment -ErrorAction SilentlyContinue
            if ($roleAssignments) {
                $auth.ExchangeOnline = $roleAssignments.Role | Select-Object -Unique
            }
            Write-Verbose "Gathered $($auth.ExchangeOnline.Count) Exchange roles."
        } catch {
            Write-Verbose "Failed to gather Exchange roles: $($_.Exception.Message)"
        }
    }

    # 4. Azure Roles
    if (Test-MtConnection -Service Azure) {
        try {
            $azContext = Get-AzContext
            if ($azContext) {
                $roleAssignments = Get-AzRoleAssignment -SignInName $azContext.Account.Id -ErrorAction SilentlyContinue
                if ($roleAssignments) {
                    $auth.Azure = $roleAssignments.RoleDefinitionName | Select-Object -Unique
                }
            }
            Write-Verbose "Gathered $($auth.Azure.Count) Azure roles."
        } catch {
            Write-Verbose "Failed to gather Azure roles: $($_.Exception.Message)"
        }
    }

    $__MtSession.Authorization = $auth
    return $auth
}
