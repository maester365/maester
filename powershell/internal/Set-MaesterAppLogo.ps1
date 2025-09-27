<#
    .SYNOPSIS
    Internal helper function to set the Maester logo for an application.

    .DESCRIPTION
    This function uploads and sets the Maester logo as the application's logo in Azure AD/Entra ID.

    .PARAMETER AppId
    The Application (Client) ID of the app to set the logo for.

    .EXAMPLE
    Set-MaesterAppLogo -AppId "12345678-1234-1234-1234-123456789012"
#>
function Set-MaesterAppLogo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $AppId
    )

    Write-Verbose "Setting Maester logo for app: $AppId"

    try {
        # Path to the Maester logo
        $logoPath = Join-Path $PSScriptRoot ".." "assets" "maester.png"

        if (-not (Test-Path $logoPath)) {
            Write-Warning "Maester logo not found at: $logoPath"
            return
        }

        # Read the logo file as bytes
        $logoBytes = [System.IO.File]::ReadAllBytes($logoPath)

        # Upload the logo
        $response = Invoke-AzRestMethod -Uri "https://graph.microsoft.com/v1.0/applications/$AppId/logo" -Method PUT -Payload $logoBytes

        if ($response.StatusCode -eq 204) {
            Write-Verbose "Successfully set Maester logo for app"
        } else {
            Write-Warning "Failed to set logo. Status: $($response.StatusCode)"
        }
    }
    catch {
        Write-Warning "Failed to set logo for app $AppId : $($_.Exception.Message)"
    }
}