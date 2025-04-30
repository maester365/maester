<#
.SYNOPSIS
    Gets the test settings for a specific test ID from the Maester config.
.DESCRIPTION
    This function retrieves the test settings for a specific test ID from the Maester config.
    It returns the settings as a hashtable, which can be used to customize the behavior of the test.
.EXAMPLE
    $testSettings = Get-MtMaesterConfigTestSetting -TestId 'Mt.1001'
    # This will return the test settings for the test with ID 'Mt.1001'.
#>

function Get-MtMaesterConfigTestSetting {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        # The ID of the test for which to retrieve the settings.
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$TestId
    )

    # Check if the Maester config is loaded
    if (-not ($__MtSession -and $__MtSession.MaesterConfig)) {
        Write-Warning "Maester config not loaded. Please run Get-MtMaesterConfig first."
        return $null
    }

    # Retrieve the test settings from the Maester config
    return $__MtSession.MaesterConfig.TestSettingsHash[$TestId]
}