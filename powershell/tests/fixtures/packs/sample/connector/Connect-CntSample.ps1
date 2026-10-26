function Connect-CntSample {
    <#
    .SYNOPSIS
    Connects to the sample service: keeps the settings it was given.
    #>
    [CmdletBinding()]
    param([string] $Tenant = 'contoso')
    Set-MtConnectionState -Value @{ Tenant = $Tenant; Settings = @{ MfaRequired = $true } } -Account "admin@$Tenant.example"
}

function Test-CntSample {
    <#
    .SYNOPSIS
    True when Connect-CntSample has run in this session.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    [bool](Get-MtConnectionState)
}

function Disconnect-CntSample {
    <#
    .SYNOPSIS
    Forgets the sample connection.
    #>
    [CmdletBinding()]
    param()
    Clear-MtConnectionState
}
