function Test-MtIntuneManagedInstallerRules {
    param (
        [string]$ApiVersion = "v1.0"
    )

    $uri = "/deviceManagement/intents"
    $response = Invoke-MtGraphRequest -RelativeUri $uri -ApiVersion $ApiVersion

    if ($response -and $response.value) {
        foreach ($intent in $response.value) {
            if ($intent.displayName -like "*Managed Installer*" -and $intent.odataType -eq "#microsoft.graph.deviceManagementIntent") {
                Add-MtTestResultDetail -Name "Managed Installer Rules Found" -Detail $intent.displayName
                return $true
            }
        }
    }

    Add-MtTestResultDetail -Name "Managed Installer Rules Missing" -Detail "No Managed Installer Rules found."
    return $false
}