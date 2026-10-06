function Use-MtModuleFunction {
    <#
    .SYNOPSIS
    Makes Maester module functions that are not exported callable from a unit test.

    .DESCRIPTION
    Check functions that became native tests are no longer exported (Maester 3.0). For each name this
    defines a global proxy function with the same parameter block, which runs the module's function in
    the module's scope with the bound parameters and forwards pipeline input object by object. Mocks
    with -ModuleName Maester apply.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]] $Name
    )
    $module = Get-Module Maester | Select-Object -First 1
    foreach ($n in $Name) {
        $command = & $module { param($c) Get-Command -Name $c -CommandType Function -ErrorAction Stop } $n
        $metadata = [System.Management.Automation.CommandMetadata]::new($command)
        $binding = [System.Management.Automation.ProxyCommand]::GetCmdletBindingAttribute($metadata)
        $paramBlock = [System.Management.Automation.ProxyCommand]::GetParamBlock($metadata)
        # Proxy with begin/process/end and a steppable pipeline (as ProxyCommand.Create does) so pipeline
        # input reaches the module function once per object instead of only the last bound values.
        $body = @"
$binding
param($paramBlock)
begin {
    `$__mtModule = Get-Module Maester | Select-Object -First 1
    # Resolved in the module's scope, so invoking it runs the function in the module's session state.
    `$__mtCommand = & `$__mtModule { param(`$__mtName) Get-Command -Name `$__mtName -CommandType Function -ErrorAction Stop } '$n'
    `$__mtPipeline = { & `$__mtCommand @PSBoundParameters }.GetSteppablePipeline(`$MyInvocation.CommandOrigin)
    `$__mtPipeline.Begin(`$PSCmdlet)
}
process { `$__mtPipeline.Process(`$_) }
end { `$__mtPipeline.End() }
"@
        Set-Item -Path "function:global:$n" -Value ([scriptblock]::Create($body))
    }
}
