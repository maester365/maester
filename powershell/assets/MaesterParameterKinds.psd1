# Parameter-kind registry (Maester 3.0 design, section 3.4). [MaesterParameter(Kind = ...)] names an entry.
# A kind tells a UI which picker to show and tells the engine how to validate a value and resolve a
# display name. Packages add kinds under their own prefix. A UI falls back to a text box for a kind it
# does not know.
#
#   Shape        what the test receives: graph-object-id | upn | arm-resource-id | string
#   Pattern      regular expression a value must match
#   Service      service the value belongs to (display names resolve only when it is connected)
#   Resolve      Graph or ARM relative URI template to read the display name; {Id} is replaced
#   DisplayName  property of the resolved object to show
#   UiHint       graph-object | arm-resource | enum | text | number | boolean
#   ODataType    for graph-object pickers
#   ResourceType for arm-resource pickers
@{
    SchemaVersion = '1.0'
    Kinds         = @{
        'Entra.User'                    = @{ Shape = 'graph-object-id'; Pattern = '^[0-9a-fA-F-]{36}$'; Service = 'Graph'; Resolve = 'users/{Id}'; DisplayName = 'displayName'; UiHint = 'graph-object'; ODataType = '#microsoft.graph.user' }
        'Entra.Group'                   = @{ Shape = 'graph-object-id'; Pattern = '^[0-9a-fA-F-]{36}$'; Service = 'Graph'; Resolve = 'groups/{Id}'; DisplayName = 'displayName'; UiHint = 'graph-object'; ODataType = '#microsoft.graph.group' }
        'Entra.ServicePrincipal'        = @{ Shape = 'graph-object-id'; Pattern = '^[0-9a-fA-F-]{36}$'; Service = 'Graph'; Resolve = 'servicePrincipals/{Id}'; DisplayName = 'displayName'; UiHint = 'graph-object'; ODataType = '#microsoft.graph.servicePrincipal' }
        'Entra.Application'             = @{ Shape = 'graph-object-id'; Pattern = '^[0-9a-fA-F-]{36}$'; Service = 'Graph'; Resolve = 'applications/{Id}'; DisplayName = 'displayName'; UiHint = 'graph-object'; ODataType = '#microsoft.graph.application' }
        'Entra.ConditionalAccessPolicy' = @{ Shape = 'graph-object-id'; Pattern = '^[0-9a-fA-F-]{36}$'; Service = 'Graph'; Resolve = 'identity/conditionalAccess/policies/{Id}'; DisplayName = 'displayName'; UiHint = 'graph-object'; ODataType = '#microsoft.graph.conditionalAccessPolicy' }
        'Entra.NamedLocation'           = @{ Shape = 'graph-object-id'; Pattern = '^[0-9a-fA-F-]{36}$'; Service = 'Graph'; Resolve = 'identity/conditionalAccess/namedLocations/{Id}'; DisplayName = 'displayName'; UiHint = 'graph-object'; ODataType = '#microsoft.graph.namedLocation' }
        'Entra.Domain'                  = @{ Shape = 'string'; Pattern = '^[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'; Service = 'Graph'; Resolve = 'domains/{Id}'; DisplayName = 'id'; UiHint = 'graph-object'; ODataType = '#microsoft.graph.domain' }
        'Entra.DirectoryRole'           = @{ Shape = 'graph-object-id'; Pattern = '^[0-9a-fA-F-]{36}$'; Service = 'Graph'; Resolve = 'roleManagement/directory/roleDefinitions/{Id}'; DisplayName = 'displayName'; UiHint = 'graph-object'; ODataType = '#microsoft.graph.unifiedRoleDefinition' }
        'Azure.Subscription'            = @{ Shape = 'string'; Pattern = '^[0-9a-fA-F-]{36}$'; Service = 'Azure'; Resolve = 'subscriptions/{Id}?api-version=2022-12-01'; DisplayName = 'displayName'; UiHint = 'arm-resource'; ResourceType = 'Microsoft.Resources/subscriptions' }
        'Azure.ResourceGroup'           = @{ Shape = 'arm-resource-id'; Pattern = '^/subscriptions/[0-9a-fA-F-]{36}/resourceGroups/[^/]+$'; Service = 'Azure'; Resolve = '{Id}?api-version=2021-04-01'; DisplayName = 'name'; UiHint = 'arm-resource'; ResourceType = 'Microsoft.Resources/resourceGroups' }
        'Azure.Resource'                = @{ Shape = 'arm-resource-id'; Pattern = '^/subscriptions/[0-9a-fA-F-]{36}/resourceGroups/[^/]+/providers/.+$'; Service = 'Azure'; Resolve = $null; DisplayName = 'name'; UiHint = 'arm-resource'; ResourceType = $null }
    }
}
