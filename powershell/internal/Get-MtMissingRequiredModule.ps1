function Get-MtMissingRequiredModule {
    <#
    .SYNOPSIS
    Internal: Returns display labels for RequiredModules entries that are not installed, or
    are installed below a declared MinimumVersion.

    .DESCRIPTION
    Used by Install-MtCustomTests to check the RequiredModules array from a repository's
    optional maester-metadata.json file against locally installed modules. Each entry
    may be a plain module name string, or an object with Name and an optional MinimumVersion.
    An invalid/unparsable MinimumVersion is ignored (treated as no minimum) rather than
    failing the whole check.

    .PARAMETER RequiredModules
    The RequiredModules array parsed from maester-metadata.json.

    .OUTPUTS
    [string[]] Display labels for modules that are missing or below MinimumVersion. Empty
    array when everything declared is satisfied.

    .EXAMPLE
    Get-MtMissingRequiredModule -RequiredModules @('Az.Accounts', @{ Name = 'Pester'; MinimumVersion = '5.5.0' })
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        # Individual elements may be $null (e.g. a JSON array with a stray null entry) - AllowNull
        # is required so PowerShell's mandatory-parameter validation doesn't reject the whole array.
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [AllowNull()]
        [object[]] $RequiredModules
    )

    $missing = [System.Collections.Generic.List[string]]::new()

    foreach ($required in $RequiredModules) {
        if ($null -eq $required) { continue }

        if ($required -is [string]) {
            $moduleName = $required
            $minimumVersion = $null
        } else {
            $moduleName = [string]$required.Name
            $minimumVersion = $null
            if ($required.PSObject.Properties.Name -contains 'MinimumVersion' -and -not [string]::IsNullOrWhiteSpace([string]$required.MinimumVersion)) {
                try {
                    $minimumVersion = [version]$required.MinimumVersion
                } catch {
                    Write-Verbose "Ignoring invalid MinimumVersion '$($required.MinimumVersion)' for module '$moduleName'."
                }
            }
        }

        if ([string]::IsNullOrWhiteSpace($moduleName)) { continue }

        $installed = Get-Module -Name $moduleName -ListAvailable -ErrorAction SilentlyContinue |
            Sort-Object -Property Version -Descending | Select-Object -First 1
        $label = if ($minimumVersion) { "$moduleName (>= $minimumVersion)" } else { $moduleName }

        if ($null -eq $installed) {
            $missing.Add($label)
        } elseif ($minimumVersion -and $installed.Version -lt $minimumVersion) {
            $missing.Add("$label - installed: $($installed.Version)")
        }
    }

    return $missing.ToArray()
}
