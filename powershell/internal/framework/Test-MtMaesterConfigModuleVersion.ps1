function Test-MtMaesterConfigModuleVersion {
    <#
    .SYNOPSIS
    Warns when loaded Maester tests were installed for an older module version.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [object] $MaesterConfig
    )

    function ConvertTo-MtComparableVersion {
        param(
            [Parameter(Mandatory = $false)]
            [AllowNull()]
            [object] $InputVersion
        )

        if ($null -eq $InputVersion) {
            return $null
        }

        if ($InputVersion -is [version]) {
            return $InputVersion
        }

        $versionString = ([string]$InputVersion).Trim()
        if ([string]::IsNullOrWhiteSpace($versionString)) {
            return $null
        }

        $numericVersion = $versionString -replace '\+.*$', '' -replace '-.*$', ''
        try {
            return [version]$numericVersion
        } catch {
            Write-Verbose "Could not parse Maester version '$InputVersion' for config comparison."
            return $null
        }
    }

    try {
        if ($null -eq $MaesterConfig) {
            Write-Verbose 'Skipping Maester config module version check because no config was loaded.'
            return $false
        }

        if ($MaesterConfig.PSObject.Properties.Name -notcontains 'ModuleVersion') {
            Write-Verbose 'Skipping Maester config module version check because ModuleVersion is missing.'
            return $false
        }

        $runningModuleVersion = Get-MtModuleVersion
        $runningComparableVersion = ConvertTo-MtComparableVersion -InputVersion $runningModuleVersion
        $configComparableVersion = ConvertTo-MtComparableVersion -InputVersion $MaesterConfig.ModuleVersion

        if ($null -eq $runningComparableVersion -or $null -eq $configComparableVersion) {
            Write-Verbose 'Skipping Maester config module version check because a version value was not comparable.'
            return $false
        }

        if ($runningComparableVersion -gt $configComparableVersion) {
            $configSource = 'maester-config.json'
            if ($MaesterConfig.PSObject.Properties.Name -contains 'ConfigSource' -and -not [string]::IsNullOrWhiteSpace($MaesterConfig.ConfigSource)) {
                $configSource = $MaesterConfig.ConfigSource
            }

            Write-Warning "You have updated the Maester module to $runningComparableVersion, but $configSource still reports ModuleVersion $configComparableVersion. Run Update-MaesterTests to update your tests."
            return $true
        }
    } catch {
        Write-Verbose "Skipping Maester config module version check because it failed: $($_.Exception.Message)"
    }

    return $false
}
