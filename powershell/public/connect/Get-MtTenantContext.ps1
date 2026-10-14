function Get-MtTenantContext {
    <#
    .SYNOPSIS
    Returns the facts about the connected tenant that decide which Maester tests apply.

    .DESCRIPTION
    The tenant context holds the tenant ID and name, tenant type (Workforce or External), cloud, the
    operating system Maester runs on, which services are connected, and the tenant's licences (service
    plan names, service plan IDs and SKU IDs). Invoke-Maester builds it once per run, records it in the
    results as TenantContext, and uses it to decide whether each test applies.

    Each fact comes from its own provider. A value set under Environment in the Maester config replaces
    the detected value: TenantType, Cloud, Licenses (a list of service plan names) and Services (a map
    of service name to true or false). A fact that cannot be detected is Unknown and never makes a test
    skip.

    .PARAMETER Service
    The services to check the connection of. Defaults to every service in the service registry.

    .PARAMETER Environment
    The Environment section of a Maester config, whose values replace detected ones.

    .EXAMPLE
    Get-MtTenantContext

    Shows the tenant type, cloud, connected services and licence state of the current connection.

    .LINK
    https://maester.dev/docs/commands/Get-MtTenantContext
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter()]
        [string[]] $Service,

        [Parameter()]
        [AllowNull()]
        [object] $Environment
    )

    Write-Verbose "Reading the tenant context$(if ($Service) { " for $($Service -join ', ')" })."
    Read-MtTenantContext -Service $Service -Environment $Environment
}
