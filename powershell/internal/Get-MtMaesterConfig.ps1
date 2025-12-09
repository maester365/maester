<#
.SYNOPSIS
    Reads the Maester config from (usually from the root of the ./tests directory)

.DESCRIPTION
    This also uses the ./custom/maester-config.json file if it exists and
    merges the settings, allowing users to override the default settings.

.EXAMPLE
    $maesterConfig = Get-MtMaesterConfig -ConfigFilePath 'C:\path\to\maester-config.json'
#>

function Get-MtMaesterConfig {
    [CmdletBinding()]
    [OutputType([object])]
    param(
        # Path to the Maester config file or the directory containing the config file (maester-config.json).
        [Parameter(Mandatory = $true)]
        $Path
    )

    Write-Verbose "Getting Maester config from $Path"

    try {
        # If the path is a directory, look for the maester-config.json file in it
        # check up 5 levels up the directory tree for the maester-config.json file
        if (Test-Path $Path -PathType Container) {
            $ConfigFilePath = Join-Path -Path $Path -ChildPath 'maester-config.json'
            if (-not (Test-Path -Path $ConfigFilePath)) {
                Write-Verbose "Config file not found in $Path. Looking for maester-config.json in parent directories."
                # Check if it's there in the ./tests folder
                $testsDir = Join-Path -Path $Path -ChildPath 'tests/maester-config.json'
                if (Test-Path -Path $testsDir) {
                    $ConfigFilePath = $testsDir
                } else {
                    # Check if there are any parent directories
                    # and look for the maester-config.json file in each parent directory
                    # up to 5 levels up
                    # This is to ensure that we can find the config file even if the user is in a subdirectory
                    # of the tests directory
                    for ($i = 1; $i -le 5; $i++) {
                        if (Test-Path -Path $ConfigFilePath) {
                            break
                        }
                        $parentDir = Split-Path -Path $Path -Parent
                        if ($parentDir -eq $Path -or [string]::IsNullOrEmpty($parentDir)) {
                            break
                        }
                        $Path = $parentDir
                        $ConfigFilePath = Join-Path -Path $Path -ChildPath 'maester-config.json'
                    }
                }
            }
        }
        # If the path is a file, use it directly
        elseif (Test-Path -Path $Path -PathType Leaf) {
            $ConfigFilePath = $Path
        }
    } catch {
        # write the error as a warning
        Write-Verbose "Error while trying to seek the config file: $_"
    }


    if (-not (Test-Path -Path $ConfigFilePath)) {
        # If we didn't find it anywhere, let's use the default config file
        Write-Verbose "Config file not found. Using default config file."
        $ConfigFilePath = Join-Path (Get-MtMaesterTestFolderPath) -ChildPath 'maester-config.json'
        if (-not (Test-Path -Path $ConfigFilePath)) {
            Write-Warning "Default config file not found at $ConfigFilePath. Please provide a valid path to the config file."
            return $null
        }
    }

    $maesterConfig = Get-Content -Path $ConfigFilePath -Raw | ConvertFrom-Json

    # Add a new property called TestSettingsHash to the config object with Id as the key for faster access
    Add-Member -InputObject $maesterConfig -MemberType NoteProperty -Name 'TestSettingsHash' -Value @{}

    foreach ($testSetting in $maesterConfig.TestSettings) {
        $maesterConfig.TestSettingsHash.Add($testSetting.Id, $testSetting)
    }

    # Read the custom config file if it exists
    $customConfigPath = Join-Path -Path (Split-Path -Path $ConfigFilePath -Parent) -ChildPath 'custom' | Join-Path -ChildPath 'maester-config.json'
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
