function Get-MdePolicyConfiguration {
    <#
    .SYNOPSIS
        Gets Microsoft Defender Antivirus policies that are assigned to devices

    .DESCRIPTION
        Retrieves configuration policies from Microsoft Graph, filters for
        Defender Antivirus policies on Windows, and optionally checks which
        ones are actually assigned based on the MDE configuration.

    .EXAMPLE
        Get-MdePolicyConfiguration

        Returns a hashtable with ConfigurationPolicies array and TotalCount.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [ValidateSet('All', 'IncludeUnassigned', 'OnlyAssigned')]
        [string]$PolicyFiltering = 'OnlyAssigned'
    )

    try {
        $mdeConfig = Get-MdeConfiguration

        if (-not $mdeConfig) {
            Write-Verbose "Unable to retrieve MDE configuration"
            return @{
                ConfigurationPolicies = @()
                TotalCount = 0
                Error = "Failed to retrieve MDE configuration"
            }
        }

        # Find Microsoft Defender Antivirus policies for Windows
        $configPolicies = @()
        if ($mdeConfig.ConfigurationPolicies) {
            $configPolicies = @($mdeConfig.ConfigurationPolicies | Where-Object {
                $_.templateReference.templateDisplayName -eq "Microsoft Defender Antivirus" -and
                $_.platforms -eq "windows10"
            })
        }

        # Apply policy filtering based on the cmdlet parameter.
        $finalConfigPolicies = @()

        switch ($PolicyFiltering) {
            { $_ -in "All", "IncludeUnassigned" } {
                # Include all matching policies regardless of assignment status
                $finalConfigPolicies = $configPolicies
                Write-Verbose "Policy filtering: $_ - Including all $($configPolicies.Count) policies"
            }
            default {
                # "OnlyAssigned" (default): only include policies with active assignments
                if ($configPolicies.Count -gt 0) {
                    Write-Verbose "Checking assignments for $($configPolicies.Count) policies"
                    foreach ($policy in $configPolicies) {
                        if (Test-MdePolicyHasAssignment -PolicyId $policy.id) {
                            $finalConfigPolicies += $policy
                        }
                    }
                    Write-Verbose "Found $($finalConfigPolicies.Count) assigned policies"
                }
            }
        }

        return @{
            ConfigurationPolicies = $finalConfigPolicies
            TotalCount = $finalConfigPolicies.Count
        }

    } catch {
        Write-Verbose "Error retrieving MDE policies: $($_.Exception.Message)"
        return @{
            ConfigurationPolicies = @()
            TotalCount = 0
            Error = "Error: $($_.Exception.Message)"
        }
    }
}
