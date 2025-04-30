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

    # If the path is a directory, look for the maester-config.json file in it
    # check up 5 levels up the directory tree for the maester-config.json file
    if (Test-Path $Path -PathType Container) {
        $ConfigFilePath = Join-Path -Path $Path -ChildPath 'maester-config.json'
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
            if ($parentDir -eq $Path) {
                break
            }
            $Path = $parentDir
            $ConfigFilePath = Join-Path -Path $Path -ChildPath 'maester-config.json'
        }
    }
    # If the path is a file, use it directly
    elseif (Test-Path -Path $Path -PathType Leaf) {
        $ConfigFilePath = $Path
    }

    if (-not (Test-Path -Path $ConfigFilePath)) {
        Write-Warning "Maester config file not found at $ConfigFilePath. Please update your tests to the latest version with Update-MtMaesterTests." -ForegroundColor Yellow
        return $null
    }

    $maesterConfig = Get-Content -Path $ConfigFilePath -Raw | ConvertFrom-Json

    # Add a new property called TestSettingsHash to the config object with Id as the key for faster access
    Add-Member -InputObject $maesterConfig -MemberType NoteProperty -Name 'TestSettingsHash' -Value @{}

    foreach ($testSetting in $maesterConfig.TestSettings) {
        $maesterConfig.TestSettingsHash.Add($testSetting.Id, $testSetting)
    }

    # Read the custom config file if it exists
    $customConfigPath = Join-Path (Split-Path -Path $ConfigFilePath -Parent) 'custom' 'maester-config.json'
    if (Test-Path $customConfigPath) {
        Write-Verbose "Custom config file found at $customConfigPath. Merging with main config."
        $customConfig = Get-Content -Path $customConfigPath -Raw | ConvertFrom-Json

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
