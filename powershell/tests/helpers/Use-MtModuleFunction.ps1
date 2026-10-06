function Use-MtModuleFunction {
    <#
    .SYNOPSIS
    Makes Maester module functions that are not exported callable from a unit test.

    .DESCRIPTION
    Check functions that became native tests are no longer exported (Maester 3.0). For each name this
    defines a function in the test's scope with the same parameter block, which runs the module's
    function in the module's scope with the bound parameters. Mocks with -ModuleName Maester apply.
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
        $body = @"
$binding
param($paramBlock)
`$__mtModule = Get-Module Maester | Select-Object -First 1
& `$__mtModule { param(`$__mtName, `$__mtParameters) & `$__mtName @__mtParameters } '$n' `$PSBoundParameters
"@
        Set-Item -Path "function:global:$n" -Value ([scriptblock]::Create($body))
    }
}
