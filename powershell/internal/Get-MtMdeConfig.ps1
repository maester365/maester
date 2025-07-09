<#
.SYNOPSIS
    Gets MDE configuration from defender-config.json

.DESCRIPTION
    Loads test settings like compliance logic and device filtering from the config file.
    Falls back to defaults if file isn't found.

.PARAMETER Path
    Path to config file or directory. Defaults to tests/Maester/Defender.

.EXAMPLE
    $config = Get-MtMdeConfig
    Loads from default location

.EXAMPLE
    $config = Get-MtMdeConfig -Path 'C:\custom'
    Loads from custom path
#>

function Get-MtMdeConfig {
    [CmdletBinding()]
    [OutputType([object])]
    param(
        # Config file path or directory
        [Parameter(Mandatory = $false)]
        $Path
    )

    # Use default location if none specified
    if (-not $Path) {
        $Path = Join-Path (Get-Location) "tests/Maester/Defender"
    }

    Write-Verbose "Getting MDE config from $Path"

    try {
        # Look for config file in directory or parent directories
        if (Test-Path $Path -PathType Container) {
            $ConfigFilePath = Join-Path -Path $Path -ChildPath 'defender-config.json'
            if (-not (Test-Path -Path $ConfigFilePath)) {
                Write-Verbose "Config file not found in $Path. Checking parent directories."
                $defenderDir = Join-Path -Path $Path -ChildPath 'tests/Maester/Defender/defender-config.json'
                if (Test-Path -Path $defenderDir) {
                    $ConfigFilePath = $defenderDir
                } else {
                    # Search up to 5 parent directories
                    for ($i = 1; $i -le 5; $i++) {
                        if (Test-Path -Path $ConfigFilePath) {
                            break
                        }
                        $parentDir = Split-Path -Path $Path -Parent
                        if ($parentDir -eq $Path -or [string]::IsNullOrEmpty($parentDir)) {
                            break
                        }
                        $Path = $parentDir
                        $ConfigFilePath = Join-Path -Path $Path -ChildPath 'tests/Maester/Defender/defender-config.json'
                    }
                }
            }
        } else {
            # Use file path directly
            $ConfigFilePath = $Path
        }

        if (-not (Test-Path -Path $ConfigFilePath)) {
            Write-Verbose "MDE config file not found at $ConfigFilePath. Using default configuration."
            # Use defaults when config file missing
            return @{
                ComplianceLogic = "AllPolicies"
                PolicyFiltering = "OnlyAssigned"
                DeviceFiltering = @{
                    OperatingSystems = @("Windows")
                    ManagementAgents = @("msSense", "mdm")
                    ComplianceStates = @("Compliant", "NonCompliant", "Unknown")
                }
                TestSpecific = @{}
            }
        }

        Write-Verbose "Loading MDE config from $ConfigFilePath"
        $configContent = Get-Content -Path $ConfigFilePath -Raw | ConvertFrom-Json

        # Merge config with defaults
        $config = @{
            ComplianceLogic = if ($configContent.ComplianceLogic) { $configContent.ComplianceLogic } else { "AllPolicies" }
            PolicyFiltering = if ($configContent.PolicyFiltering) { $configContent.PolicyFiltering } else { "OnlyAssigned" }
            DeviceFiltering = @{
                OperatingSystems = if ($configContent.DeviceFiltering.OperatingSystems) { $configContent.DeviceFiltering.OperatingSystems } else { @("Windows") }
                ManagementAgents = if ($configContent.DeviceFiltering.ManagementAgents) { $configContent.DeviceFiltering.ManagementAgents } else { @("msSense", "mdm") }
                ComplianceStates = if ($configContent.DeviceFiltering.ComplianceStates) { $configContent.DeviceFiltering.ComplianceStates } else { @("Compliant", "NonCompliant", "Unknown") }
            }
            TestSpecific = if ($configContent.TestSpecific) { $configContent.TestSpecific } else { @{} }
        }

        Write-Verbose "MDE config loaded successfully"
        return $config

    } catch {
        Write-Warning "Failed to load MDE config from $ConfigFilePath`: $($_.Exception.Message). Using default configuration."
        # Fall back to defaults on error
        return @{
            ComplianceLogic = "AllPolicies"
            PolicyFiltering = "OnlyAssigned"
            DeviceFiltering = @{
                OperatingSystems = @("Windows")
                ManagementAgents = @("msSense", "mdm")
                ComplianceStates = @("Compliant", "NonCompliant", "Unknown")
            }
            TestSpecific = @{}
        }
    }
}