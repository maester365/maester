function Get-MtMaesterConfig {
    <#
    .SYNOPSIS
    Reads the Maester config from (usually from the root of the ./tests directory)

    .DESCRIPTION
    This also uses the ./custom/maester-config.json file if it exists and
    merges the settings, allowing users to override the default settings.

    .EXAMPLE
    $maesterConfig = Get-MtMaesterConfig -ConfigFilePath 'C:\path\to\maester-config.json'
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        # Path to the Maester config file or the directory containing the config file (maester-config.json).
        [Parameter(Mandatory = $true)]
        $Path,

        # Optional tenant ID. When provided, looks for maester-config.{TenantId}.json first,
        # then falls back to maester-config.json.
        [Parameter(Mandatory = $false)]
        [string] $TenantId
    )

    Write-Verbose "Getting Maester config from $Path"

    # Helper to find a config file by name in a directory, walking up to 5 parent levels
    function Find-ConfigFile {
        param([string]$SearchPath, [string]$FileName)

        if (Test-Path $SearchPath -PathType Container) {
            $candidate = Join-Path -Path $SearchPath -ChildPath $FileName
            if (Test-Path -Path $candidate) { return $candidate }

            # Check tests subfolder
            $testsCandidate = Join-Path -Path $SearchPath -ChildPath "tests/$FileName"
            if (Test-Path -Path $testsCandidate) { return $testsCandidate }

            # Walk up to 5 parent directories
            $currentDir = $SearchPath
            for ($i = 1; $i -le 5; $i++) {
                $parentDir = Split-Path -Path $currentDir -Parent
                if ($parentDir -eq $currentDir -or [string]::IsNullOrEmpty($parentDir)) { break }
                $currentDir = $parentDir
                $candidate = Join-Path -Path $currentDir -ChildPath $FileName
                if (Test-Path -Path $candidate) { return $candidate }
            }
        }

        return $null
    }

    $ConfigFilePath = $null

    try {
        # If a valid TenantId (GUID) is provided, look for tenant-specific config first
        $isValidTenantId = $TenantId -as [guid]
        if ($isValidTenantId) {
            $tenantFileName = "maester-config.$TenantId.json"
            $ConfigFilePath = Find-ConfigFile -SearchPath $Path -FileName $tenantFileName
            if ($ConfigFilePath) {
                Write-Verbose "Found tenant-specific config: $ConfigFilePath"
            } else {
                Write-Verbose "No tenant-specific config ($tenantFileName) found. Falling back to default."
            }
        }

        # Fall back to the default maester-config.json
        if (-not $ConfigFilePath) {
            # If Path is a direct file reference, use it as-is (preserves original behavior)
            if (Test-Path -Path $Path -PathType Leaf) {
                $ConfigFilePath = $Path
            } else {
                $ConfigFilePath = Find-ConfigFile -SearchPath $Path -FileName 'maester-config.json'
            }
        }
    } catch {
        Write-Verbose "Error while trying to seek the config file: $_"
    }

    if (-not $ConfigFilePath -or -not (Test-Path -Path $ConfigFilePath)) {
        # If we didn't find it anywhere, let's use the default config file
        Write-Verbose "Config file not found. Using default config file."
        $ConfigFilePath = Join-Path (Get-MtMaesterTestFolderPath) -ChildPath 'maester-config.json'
        if (-not (Test-Path -Path $ConfigFilePath)) {
            Write-Warning "Default config file not found at $ConfigFilePath. Please provide a valid path to the config file."
            return $null
        }
    }

    Write-Verbose "Loading Maester config from: $ConfigFilePath"
    $maesterConfig = Get-Content -Path $ConfigFilePath -Raw | ConvertFrom-Json

    # Store the source file name so the report can show which config was loaded
    $configFileName = Split-Path -Path $ConfigFilePath -Leaf
    Add-Member -InputObject $maesterConfig -MemberType NoteProperty -Name 'ConfigSource' -Value $configFileName

    # Add a new property called TestSettingsHash to the config object with Id as the key for faster access
    Add-Member -InputObject $maesterConfig -MemberType NoteProperty -Name 'TestSettingsHash' -Value @{}

    foreach ($testSetting in $maesterConfig.TestSettings) {
        $maesterConfig.TestSettingsHash.Add($testSetting.Id, $testSetting)
    }

    # Read the custom config file if it exists
    $customConfigPath = Join-Path -Path (Split-Path -Path $ConfigFilePath -Parent) -ChildPath 'Custom' | Join-Path -ChildPath 'maester-config.json'
    if (Test-Path $customConfigPath) {
        Write-Verbose "Custom config file found at $customConfigPath. Merging with main config."
        $customConfig = Get-Content -Path $customConfigPath -Raw | ConvertFrom-Json

        # Go through each GlobalSetting in custom and override the main config if it exists, otherwise append
        foreach ($property in $customConfig.GlobalSettings.PSObject.Properties) {
            if ($maesterConfig.GlobalSettings.PSObject.Properties.Name -contains $property.Name) {
                Write-Verbose "Updating GlobalSetting `"$($property.Name)`" from custom config."
                $maesterConfig.GlobalSettings.$($property.Name) = $property.Value
            } else {
                Write-Verbose "Adding GlobalSetting `"$($property.Name)`" from custom config."
                Add-Member -InputObject $maesterConfig.GlobalSettings -MemberType NoteProperty -Name $property.Name -Value $property.Value
            }
        }

        # Go through each TestSetting in custom and override the main config if it exists
        foreach ($customSetting in $customConfig.TestSettings) {
            $mainTestSetting = $maesterConfig.TestSettingsHash[$customSetting.Id]
            if ($mainTestSetting) {
                Write-Verbose "Updating TestSetting with Id $($customSetting.Id) from custom config."
                # Update the existing properties (right now only Severity is supported)
                $mainTestSetting.Severity = $customSetting.Severity
            }
        }

    } else {
        Write-Verbose "No custom config file found. Using main config only."
    }

    return $maesterConfig
}
