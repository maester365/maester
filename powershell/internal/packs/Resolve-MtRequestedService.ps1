function Resolve-MtRequestedService {
    <#
    .SYNOPSIS
    Checks the -Service values of Connect-Maester and Test-MtConnection: Maester's own names, or the service of an installed pack's connector.

    .DESCRIPTION
    Replaces a fixed ValidateSet, so pack connectors can add services (Maester Packs design, section 6.2).
    The installed packs are read through the loader gate the first time a name is not one of Maester's.
    Returns BuiltIn (Maester's names, as given) and Pack (pack service names, as registered). Throws for
    a name nobody provides, listing the names that are available.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter()] [AllowEmptyCollection()] [string[]] $Service = @(),
        # Maester's own names that the calling command accepts.
        [Parameter(Mandatory)] [string[]] $BuiltIn
    )

    $own = [System.Collections.Generic.List[string]]::new()
    $pack = [System.Collections.Generic.List[string]]::new()
    foreach ($name in $Service) {
        $match = $BuiltIn | Where-Object { $_ -eq $name } | Select-Object -First 1
        if ($match) { $own.Add($match); continue }
        $registry = (Get-MtServiceRegistry).Services
        if (-not ($registry.ContainsKey($name) -and $registry[$name].ContainsKey('Pack')) -and $null -eq $script:__MtPackSet) {
            $null = Initialize-MtPackSet
            $registry = (Get-MtServiceRegistry).Services
        }
        $key = $registry.Keys | Where-Object { $_ -eq $name -and $registry[$_].ContainsKey('Pack') } | Select-Object -First 1
        if ($key) { $pack.Add([string]$key); continue }
        $packNames = @($registry.Keys | Where-Object { $registry[$_].ContainsKey('Pack') } | Sort-Object)
        throw "'$name' is not a service Maester knows. Use one of: $(@($BuiltIn) + $packNames -join ', '). A service of a Maester Pack is available once the pack is installed (Get-MtConnector lists them)."
    }
    [pscustomobject]@{ BuiltIn = [string[]]$own.ToArray(); Pack = [string[]]$pack.ToArray() }
}

function Get-MtServiceCompletion {
    <#
    .SYNOPSIS
    Tab completion for -Service: Maester's own names, then the services of the packs this session has read.
    #>
    [CmdletBinding()]
    [OutputType([System.Management.Automation.CompletionResult])]
    param(
        [Parameter(Mandatory)] [string[]] $BuiltIn,
        [Parameter()] [AllowEmptyString()] [string] $WordToComplete = ''
    )
    $registry = (Get-MtServiceRegistry).Services
    $names = @($BuiltIn) + @($registry.Keys | Where-Object { $registry[$_].ContainsKey('Pack') } | Sort-Object)
    foreach ($n in ($names | Where-Object { $_ -like "$WordToComplete*" })) {
        [System.Management.Automation.CompletionResult]::new($n, $n, 'ParameterValue', $n)
    }
}
