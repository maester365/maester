function Test-MtIntuneAppControl {
    param (
        [string]$ApiVersion = "v1.0"
    )

    $uri = "/deviceManagement/configurationPolicies"
    $response = Invoke-MtGraphRequest -RelativeUri $uri -ApiVersion $ApiVersion

    if ($response -and $response.value) {
        foreach ($policy in $response.value) {
            if ($policy.displayName -like "*App Control*" -and $policy.odataType -eq "#microsoft.graph.deviceManagementConfigurationPolicy") {
                Add-MtTestResultDetail -Name "App Control Policy Found" -Detail $policy.displayName
                return $true
            }
        }
    }

    Add-MtTestResultDetail -Name "App Control Policy Missing" -Detail "No App Control for Business policy found."
    return $false
}