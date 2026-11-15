function Get-MtGraphFixtureContext {
    <#
    .SYNOPSIS
    Internal: Returns the Microsoft Graph context that Graph replay reports instead of Get-MgContext.

    .DESCRIPTION
    In replay there is no Connect-MgGraph session. Enable-MtGraphFixture -Mode Replay makes Get-MgContext, inside
    the Maester module, return this object, so that Test-MtConnection, Test-MtContext, Invoke-MtGraphRequest and the
    checks that read the tenant ID, scopes or auth type behave as they did when the fixture set was recorded.

    The values come from the context section of the fixture set's scenario.json. A hand-written fixture set
    without one gets a delegated connection to a fake tenant with every scope Maester asks for.

    .EXAMPLE
    Get-MtGraphFixtureContext

    Returns TenantId, Account, AuthType, Scopes, Environment and the other properties checks read.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    $state = $__MtSession.GraphFixture
    if (-not $state -or $state.Mode -ne 'Replay') { return $null }
    if ($state.Context) { return $state.Context }

    $recorded = $state.Scenario.context
    $value = { param($name, $default) if ($recorded -and $recorded.PSObject.Properties[$name] -and $null -ne $recorded.$name) { $recorded.$name } else { $default } }
    $scopes = & $value 'scopes' $null
    if ($null -eq $scopes) { $scopes = @(Get-MtGraphScope -SendMail -SendTeamsMessage -IncludePreview) }

    $state.Context = [pscustomobject]@{
        PSTypeName          = 'Maester.GraphFixtureContext'
        TenantId            = [string](& $value 'tenantId' 'fa4efa4e-0000-0000-0000-000000000000')
        Account             = [string](& $value 'account' 'admin@fake000000.onmicrosoft.com')
        AuthType            = [string](& $value 'authType' 'Delegated')
        ClientId            = [string](& $value 'clientId' 'fa4efa4e-0000-0000-0000-000000000001')
        Scopes              = [string[]]@($scopes)
        Environment         = [string](& $value 'environment' 'Global')
        AppName             = 'Maester Graph replay'
        ContextScope        = 'Process'
        TokenCredentialType = 'Replay'
    }
    return $state.Context
}
